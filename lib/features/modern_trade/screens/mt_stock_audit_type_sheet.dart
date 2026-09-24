import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_stock_audit_create_screen.dart';

/// Shows a bottom sheet to select the Modern Trade Stock Audit type before entering
/// the product selection and count screen.
Future<bool?> showMtAuditTypePicker(
  BuildContext context, {
  required int outletId,
  required String outletName,
  int? visitId,
}) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MtAuditTypeSheetContent(
      outletId: outletId,
      outletName: outletName,
      visitId: visitId,
    ),
  );
}

class _MtAuditTypeSheetContent extends StatefulWidget {
  final int outletId;
  final String outletName;
  final int? visitId;

  const _MtAuditTypeSheetContent({
    required this.outletId,
    required this.outletName,
    this.visitId,
  });

  @override
  State<_MtAuditTypeSheetContent> createState() => _MtAuditTypeSheetContentState();
}

class _MtAuditTypeSheetContentState extends State<_MtAuditTypeSheetContent> {
  bool _isLoading = true;
  bool _hasOpening = false;
  bool _hasClosing = false;
  bool _isClosingConfirmed = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final provider = context.read<ModernTradeProvider>();
    final status = await provider.checkTodayAudits(widget.outletId);
    if (!mounted) return;
    setState(() {
      _hasOpening = status.hasOpening;
      _hasClosing = status.hasClosing;
      _isClosingConfirmed = status.isClosingConfirmed;
      _isLoading = false;
    });
  }

  void _onSelectType(String typeKey) async {
    Navigator.pop(context); // Close sheet
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MtStockAuditCreateScreen(
          outletId: widget.outletId,
          outletName: widget.outletName,
          visitId: widget.visitId,
          initialType: typeKey,
        ),
      ),
    );
    if (result == true && mounted) {
      // Refresh or notify if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Audit Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.outletName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // Option 1: Opening Stock
              _buildTypeOption(
                title: 'Opening Stock',
                subtitle: 'Record initial shelf & warehouse stock for the day',
                typeKey: 'opening_stock',
                icon: Icons.wb_sunny_outlined,
                primaryColor: const Color(0xFFE65100),
                bgColor: const Color(0xFFFFF3E0),
                isDisabled: _hasOpening,
                disabledReason: _hasOpening ? 'Already completed for today' : null,
              ),
              const SizedBox(height: 12),

              // Option 2: Stock In
              _buildTypeOption(
                title: 'Stock In',
                subtitle: 'Log incoming stock deliveries received at outlet',
                typeKey: 'stock_in',
                icon: Icons.move_to_inbox_outlined,
                primaryColor: const Color(0xFF0288D1),
                bgColor: const Color(0xFFE1F5FE),
                isDisabled: !_hasOpening || _isClosingConfirmed,
                disabledReason: !_hasOpening
                    ? 'Opening Stock is required first'
                    : _isClosingConfirmed
                        ? 'Closing Stock is already confirmed'
                        : null,
              ),
              const SizedBox(height: 12),

              // Option 3: Closing Stock
              _buildTypeOption(
                title: 'Closing Stock',
                subtitle: 'Final end-of-day stock count and reconciliation',
                typeKey: 'closing_stock',
                icon: Icons.task_alt_outlined,
                primaryColor: const Color(0xFF7B1FA2),
                bgColor: const Color(0xFFF3E5F5),
                isDisabled: !_hasOpening || _hasClosing,
                disabledReason: !_hasOpening
                    ? 'Opening Stock is required first'
                    : _hasClosing
                        ? 'Already completed for today'
                        : null,
              ),

              if (_hasOpening && _isClosingConfirmed) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All stock audits for today are completed and closed.',
                          style: TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required String title,
    required String subtitle,
    required String typeKey,
    required IconData icon,
    required Color primaryColor,
    required Color bgColor,
    required bool isDisabled,
    String? disabledReason,
  }) {
    return InkWell(
      onTap: isDisabled
          ? () {
              if (disabledReason != null) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(disabledReason),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          : () => _onSelectType(typeKey),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled ? Colors.grey.shade300 : primaryColor.withValues(alpha: 0.3),
              width: isDisabled ? 1.0 : 1.5,
            ),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (disabledReason != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              disabledReason,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isDisabled ? Icons.lock_outline : Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDisabled ? Colors.grey.shade400 : primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
