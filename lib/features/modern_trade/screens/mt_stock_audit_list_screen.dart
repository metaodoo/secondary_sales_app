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
import 'package:secondary_sales/features/modern_trade/screens/mt_stock_audit_create_screen.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_stock_audit_detail_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'all';
  final String _selectedState = 'all';
  DateTime? _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAudits());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchAudits() {
    final dateStr = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;
    context.read<ModernTradeProvider>().fetchStockAudits(
      outletId: widget.outletId,
      type: _selectedType,
      state: _selectedState,
      date: dateStr,
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchAudits();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModernTradeProvider>();
    final List<MtStockAudit> audits = provider.stockAudits;
    final List<MtStockAudit> filtered = _searchController.text.trim().isEmpty
        ? audits
        : audits.where((MtStockAudit a) {
            final q = _searchController.text.trim().toLowerCase();
            return a.name.toLowerCase().contains(q) ||
                (a.outletName != null && a.outletName!.toLowerCase().contains(q)) ||
                (a.outletCode != null && a.outletCode!.toLowerCase().contains(q));
          }).toList();

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
                onPressed: _fetchAudits,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search audit, outlet...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
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
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: AppColors.primaryStrong),
                          const SizedBox(width: 6),
                          Text(
                            _selectedDate != null
                                ? DateFormat('dd MMM').format(_selectedDate!)
                                : 'All',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Filter Pills
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
            const SizedBox(height: 8),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No stock audits found for this date',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _fetchAudits(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final audit = filtered[index];
                              return _StockAuditCard(
                                audit: audit,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MtStockAuditDetailScreen(auditId: audit.id),
                                    ),
                                  );
                                  _fetchAudits();
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
            if (provider.checkedInOutletId != null) {
              final outlet = provider.outlets
                  .where((o) => o.id == provider.checkedInOutletId)
                  .firstOrNull;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MtStockAuditCreateScreen(
                    outletId: provider.checkedInOutletId,
                    outletName: outlet?.name ?? widget.outletName,
                    visitId: provider.currentVisitId,
                  ),
                ),
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
              _fetchAudits();
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
        _fetchAudits();
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
        ? DateFormat('dd MMM yyyy, hh:mm a').format(audit.date!)
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
