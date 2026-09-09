import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_stock_audit.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_stock_audit_create_screen.dart';

class MtStockAuditDetailScreen extends StatefulWidget {
  final int auditId;

  const MtStockAuditDetailScreen({
    super.key,
    required this.auditId,
  });

  @override
  State<MtStockAuditDetailScreen> createState() => _MtStockAuditDetailScreenState();
}

class _MtStockAuditDetailScreenState extends State<MtStockAuditDetailScreen> {
  MtStockAudit? _audit;
  bool _isLoading = true;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final audit = await context.read<ModernTradeProvider>().fetchStockAuditDetail(widget.auditId);
    if (!mounted) return;
    setState(() {
      _audit = audit;
      _isLoading = false;
    });
  }

  Future<void> _confirmAudit() async {
    if (_audit == null || _audit!.isConfirmed) return;
    setState(() => _isConfirming = true);

    try {
      final updated = await context.read<ModernTradeProvider>().confirmStockAudit(widget.auditId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock Audit confirmed successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      setState(() => _audit = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

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
    final audit = _audit;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: audit?.name ?? 'Stock Audit',
              subtitle: audit?.outletName ?? 'Modern Trade',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadDetail,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : audit == null
                      ? const Center(child: Text('Audit details not found.'))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Info Card
                            Container(
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getTypeColor(audit.type).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              audit.typeLabel,
                                              style: TextStyle(
                                                color: _getTypeColor(audit.type),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
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
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                    Icons.storefront_outlined,
                                    'Outlet',
                                    audit.outletName ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.person_outline,
                                    'Employee',
                                    audit.employeeName ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.calendar_today_outlined,
                                    'Date',
                                    audit.date != null
                                        ? DateFormat('dd MMM yyyy, hh:mm a').format(audit.date!)
                                        : 'N/A',
                                  ),
                                  if (audit.notes.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      Icons.notes_outlined,
                                      'Notes',
                                      audit.notes,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Line Items Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Audited Products (${audit.lines.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'Total: ${audit.totalStockCount}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.primaryStrong,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Line Items List
                            ...audit.lines.map((line) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.borderSoft),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              line.productName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (line.lotName != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Lot: ${line.lotName}${line.expirationDate != null ? ' (Exp: ${DateFormat('yyyy-MM-dd').format(line.expirationDate!)})' : ''}',
                                                style: const TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${line.stockCount} ${line.uomName ?? ''}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
            ),
            if (audit != null && !audit.isConfirmed)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFDDE6F2))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MtStockAuditCreateScreen(
                                outletId: audit.outletId,
                                outletName: audit.outletName,
                                editAudit: audit,
                              ),
                            ),
                          );
                          _loadDetail();
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryStrong),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Edit Audit',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStrong),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isConfirming ? null : _confirmAudit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isConfirming
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Confirm Audit',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
