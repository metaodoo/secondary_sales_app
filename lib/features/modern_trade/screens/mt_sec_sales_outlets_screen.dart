import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_sec_orders_list_screen.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_employee_filter_sheet.dart';

class _OutletSalesSummary {
  final int id;
  final String name;
  final String? code;
  final String? address;
  int orderCount;
  double totalSoldQty;
  DateTime? latestDate;

  _OutletSalesSummary({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.orderCount = 0,
    this.totalSoldQty = 0.0,
    this.latestDate,
  });
}

class MtSecSalesOutletsScreen extends StatefulWidget {
  const MtSecSalesOutletsScreen({super.key});

  @override
  State<MtSecSalesOutletsScreen> createState() => _MtSecSalesOutletsScreenState();
}

class _MtSecSalesOutletsScreenState extends State<MtSecSalesOutletsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _searchQuery = '';
  int? _selectedEmployeeId;
  String? _selectedEmployeeName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = context.read<ModernTradeProvider>();
    try {
      await Future.wait([
        provider.fetchMtSecondarySales(page: 1, pageSize: 100, employeeId: _selectedEmployeeId),
        if (provider.outlets.isEmpty) provider.fetchOutlets(),
      ]);
    } catch (e) {
      debugPrint('[MtSecSalesOutlets] Error loading orders: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_OutletSalesSummary> _buildSummaries(ModernTradeProvider provider) {
    final Map<int, _OutletSalesSummary> summaryMap = {};

    for (final order in provider.secSaleOrders) {
      if (order.outletId == null) continue;
      final oid = order.outletId!;
      final oname = order.outletName ?? 'Outlet #$oid';

      if (!summaryMap.containsKey(oid)) {
        final outletMatch = provider.outlets.where((o) => o.id == oid).firstOrNull;
        summaryMap[oid] = _OutletSalesSummary(
          id: oid,
          name: oname,
          code: outletMatch?.ssCode,
          address: outletMatch?.street,
          orderCount: 1,
          totalSoldQty: order.totalSoldQty,
          latestDate: order.date,
        );
      } else {
        final existing = summaryMap[oid]!;
        existing.orderCount += 1;
        existing.totalSoldQty += order.totalSoldQty;
        if (order.date != null) {
          if (existing.latestDate == null || order.date!.isAfter(existing.latestDate!)) {
            existing.latestDate = order.date;
          }
        }
      }
    }

    final list = summaryMap.values.toList();
    list.sort((a, b) {
      if (a.latestDate == null && b.latestDate == null) return 0;
      if (a.latestDate == null) return 1;
      if (b.latestDate == null) return -1;
      return b.latestDate!.compareTo(a.latestDate!);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModernTradeProvider>();
    final summaries = _buildSummaries(provider);

    final filtered = summaries.where((s) {
      final q = _searchQuery.toLowerCase();
      final name = s.name.toLowerCase();
      final code = (s.code ?? '').toLowerCase();
      final addr = (s.address ?? '').toLowerCase();
      return name.contains(q) || code.contains(q) || addr.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: 'Audit Sales',
              subtitle: 'Select an outlet to view sales',
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              trailing: IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadData,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search outlet by name, code...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),
            ),
            // Employee filter button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: InkWell(
                onTap: () {
                  MtEmployeeFilterSheet.show(
                    context,
                    selectedEmployeeId: _selectedEmployeeId,
                    extraEmployees: [
                      for (final o in provider.secSaleOrders)
                        if (o.employeeId != null && o.employeeName != null)
                          {'id': o.employeeId!, 'name': o.employeeName!},
                    ],
                    onSelected: (id, name) {
                      setState(() {
                        _selectedEmployeeId = id;
                        _selectedEmployeeName = name;
                      });
                      _loadData();
                    },
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedEmployeeId != null
                        ? AppColors.primarySoft.withValues(alpha: 0.3)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedEmployeeId != null
                          ? AppColors.primaryStrong
                          : AppColors.borderSoft,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: _selectedEmployeeId != null ? AppColors.primaryStrong : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _selectedEmployeeName != null
                              ? 'Sold by: $_selectedEmployeeName'
                              : 'Filter by Employee (All)',
                          style: TextStyle(
                            fontWeight: _selectedEmployeeId != null ? FontWeight.bold : FontWeight.w600,
                            fontSize: 12,
                            color: _selectedEmployeeId != null ? AppColors.primaryStrong : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedEmployeeId != null)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedEmployeeId = null;
                              _selectedEmployeeName = null;
                            });
                            _loadData();
                          },
                          child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                        )
                      else
                        const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} ${filtered.length == 1 ? 'Outlet' : 'Outlets'} with Sales',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No outlets matching "$_searchQuery"'
                                      : 'No outlets found with secondary sales.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final dateFormatted = item.latestDate != null
                                  ? DateFormat('dd MMM yyyy').format(item.latestDate!.toLocal())
                                  : null;

                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MtSecOrdersListScreen(
                                        outletId: item.id,
                                        outletName: item.name,
                                        initialEmployeeId: _selectedEmployeeId,
                                        initialEmployeeName: _selectedEmployeeName,
                                      ),
                                    ),
                                  ).then((_) => _loadData());
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.borderSoft),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.primaryStrong.withValues(alpha: 0.12),
                                        radius: 22,
                                        child: const Icon(
                                          Icons.storefront_outlined,
                                          color: AppColors.primaryStrong,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (item.code != null && item.code!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Code: ${item.code}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                            if (item.address != null && item.address!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                item.address!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceTint,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${item.orderCount} ${item.orderCount == 1 ? 'Order' : 'Orders'}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.primaryStrong,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${item.totalSoldQty.toStringAsFixed(item.totalSoldQty.truncateToDouble() == item.totalSoldQty ? 0 : 2)} Units',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF059669),
                                                    ),
                                                  ),
                                                ),
                                                if (dateFormatted != null)
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                                    child: Text(
                                                      'Last: $dateFormatted',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors.textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.textSecondary,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
