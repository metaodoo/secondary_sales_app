import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/access/permission_gate.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_stock_audit.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_outlets_screen.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_stock_audit_detail_screen.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_stock_audit_type_sheet.dart';

class MtStockAuditListScreen extends StatefulWidget {
  final int? outletId;
  final String? outletName;
  final int? visitId;

  const MtStockAuditListScreen({
    super.key,
    this.outletId,
    this.outletName,
    this.visitId,
  });

  @override
  State<MtStockAuditListScreen> createState() => _MtStockAuditListScreenState();
}

class _MtStockAuditListScreenState extends State<MtStockAuditListScreen> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  String _selectedType = 'all';
  final String _selectedState = 'all';
  DateTime? _dateFrom = DateTime.now();
  DateTime? _dateTo = DateTime.now();
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAudits(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchAudits();
    }
  }

  Future<void> _fetchAudits({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _isLoadingMore = false;
    }
    if (!reset && (!_hasMore || _isLoadingMore)) {
      return;
    }

    if (mounted) {
      setState(() {
        if (!reset) _isLoadingMore = true;
      });
    }

    final dateFromStr = _dateFrom != null
        ? DateFormat('yyyy-MM-dd').format(_dateFrom!)
        : null;
    final dateToStr = _dateTo != null
        ? DateFormat('yyyy-MM-dd').format(_dateTo!)
        : null;
    final searchStr = _searchController.text.trim().isNotEmpty
        ? _searchController.text.trim()
        : null;

    final provider = context.read<ModernTradeProvider>();
    await provider.fetchStockAudits(
      page: _page,
      pageSize: _pageSize,
      outletId: widget.outletId,
      type: _selectedType,
      state: _selectedState,
      dateFrom: dateFromStr,
      dateTo: dateToStr,
      search: searchStr,
    );

    if (mounted) {
      setState(() {
        _hasMore = provider.stockAudits.length < provider.stockAuditsTotal;
        if (_hasMore) {
          _page += 1;
        }
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialStart = _dateFrom ?? now;
    final initialEnd = _dateTo ?? now;
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryStrong,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
      _fetchAudits(reset: true);
    }
  }

  void _clearDateFilter() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    _fetchAudits(reset: true);
  }

  void _resetToToday() {
    setState(() {
      _dateFrom = DateTime.now();
      _dateTo = DateTime.now();
    });
    _fetchAudits(reset: true);
  }

  String get _dateRangeDisplay {
    if (_dateFrom == null && _dateTo == null) {
      return 'All Dates';
    }
    if (_dateFrom != null && _dateTo != null) {
      final isSameDay = _dateFrom!.year == _dateTo!.year &&
          _dateFrom!.month == _dateTo!.month &&
          _dateFrom!.day == _dateTo!.day;
      if (isSameDay) {
        final now = DateTime.now();
        final isToday = _dateFrom!.year == now.year &&
            _dateFrom!.month == now.month &&
            _dateFrom!.day == now.day;
        return isToday ? 'Today (${DateFormat('dd MMM').format(_dateFrom!)})' : DateFormat('dd MMM yyyy').format(_dateFrom!);
      }
      return '${DateFormat('dd MMM').format(_dateFrom!)} - ${DateFormat('dd MMM').format(_dateTo!)}';
    }
    if (_dateFrom != null) {
      return 'From ${DateFormat('dd MMM').format(_dateFrom!)}';
    }
    return 'Until ${DateFormat('dd MMM').format(_dateTo!)}';
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchAudits(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModernTradeProvider>();
    final List<MtStockAudit> audits = provider.stockAudits;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: 'Stock Audits',
              subtitle: widget.outletName != null
                  ? widget.outletName!
                  : 'Modern Trade Secondary Sales',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => _fetchAudits(reset: true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search audit, outlet...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _fetchAudits(reset: true);
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.borderSoft),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _selectDateRange,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (_dateFrom != null || _dateTo != null)
                              ? AppColors.primaryStrong
                              : AppColors.borderSoft,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primaryStrong),
                          const SizedBox(width: 6),
                          Text(
                            _dateRangeDisplay,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          if (_dateFrom != null || _dateTo != null) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: _clearDateFilter,
                              child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Filter Pills & Total Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${provider.stockAuditsTotal} Audits found',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_dateFrom == null && _dateTo == null)
                    InkWell(
                      onTap: _resetToToday,
                      child: const Text(
                        'Set to Today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryStrong,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildTypeChip('All Types', 'all'),
                  const SizedBox(width: 8),
                  _buildTypeChip('Opening Stock', 'opening_stock'),
                  const SizedBox(width: 8),
                  _buildTypeChip('Stock In', 'stock_in'),
                  const SizedBox(width: 8),
                  _buildTypeChip('Closing Stock', 'closing_stock'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: provider.isLoading && audits.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : audits.isEmpty
                      ? const Center(
                          child: Text(
                            'No stock audits found for the selected filter.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _fetchAudits(reset: true),
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: audits.length + (_isLoadingMore ? 1 : 0),
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              if (index >= audits.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final audit = audits[index];
                              return _StockAuditCard(
                                audit: audit,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MtStockAuditDetailScreen(auditId: audit.id),
                                    ),
                                  );
                                  _fetchAudits(reset: true);
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: PermissionGate(
        resourceKey: AppAction.mtSecStockAuditCreate,
        child: FloatingActionButton.extended(
          onPressed: () async {
            final provider = context.read<ModernTradeProvider>();
            final targetOutletId = provider.checkedInOutletId ?? widget.outletId;
            if (targetOutletId != null) {
              final outlet = provider.outlets
                  .where((o) => o.id == targetOutletId)
                  .firstOrNull;
              final outletName = outlet?.name ?? widget.outletName ?? 'Modern Trade';
              await showMtAuditTypePicker(
                context,
                outletId: targetOutletId,
                outletName: outletName,
                visitId: provider.currentVisitId ?? widget.visitId,
              );
            } else {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MtOutletsScreen(),
                ),
              );
            }
            if (mounted) {
              _fetchAudits(reset: true);
            }
          },
          backgroundColor: AppColors.primaryStrong,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'New Audit',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String typeKey) {
    final isSelected = _selectedType == typeKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryStrong,
      backgroundColor: Colors.white,
      onSelected: (_) {
        setState(() => _selectedType = typeKey);
        _fetchAudits(reset: true);
      },
    );
  }
}

class _StockAuditCard extends StatelessWidget {
  final MtStockAudit audit;
  final VoidCallback onTap;

  const _StockAuditCard({required this.audit, required this.onTap});

  Color _getTypeColor(String type) {
    switch (type) {
      case 'opening_stock':
        return const Color(0xFFE65100);
      case 'stock_in':
        return const Color(0xFF0288D1);
      case 'closing_stock':
        return const Color(0xFF7B1FA2);
      default:
        return AppColors.primaryStrong;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(audit.type);
    final dateFormatted = audit.date != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(audit.date!.toLocal())
        : 'N/A';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  audit.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        audit.typeLabel,
                        style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: audit.isConfirmed
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        audit.isConfirmed ? 'CONFIRMED' : 'DRAFT',
                        style: TextStyle(
                          color: audit.isConfirmed
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF512DA8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (audit.outletName != null)
              Row(
                children: [
                  const Icon(Icons.storefront_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      audit.outletName!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      dateFormatted,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                Text(
                  '${audit.totalLines} Items • Qty: ${audit.totalStockCount % 1 == 0 ? audit.totalStockCount.toInt() : audit.totalStockCount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primaryStrong,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
