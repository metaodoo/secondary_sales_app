import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/models/routes/visit_reason.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';

class VisitReasonDialog extends StatefulWidget {
  const VisitReasonDialog({super.key});

  static Future<VisitReasonSelection?> show(BuildContext context) {
    return showModalBottomSheet<VisitReasonSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VisitReasonDialog(),
    );
  }

  @override
  State<VisitReasonDialog> createState() => _VisitReasonDialogState();
}

class _VisitReasonDialogState extends State<VisitReasonDialog> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _saleAmountController = TextEditingController();
  VisitReason? _selectedReason;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReasons();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _saleAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    final routeProv = context.read<RouteProvider>();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final fetched = await routeProv.fetchVisitReasons();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (fetched.isNotEmpty) {
          _selectedReason = fetched.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _confirm() {
    if (_selectedReason == null) return;
    double? saleAmount;
    final canEnterSaleAmount = context.read<AuthProvider>().canDo(AppAction.visitSaleAmount);
    if (_selectedReason!.isSale && canEnterSaleAmount) {
      final text = _saleAmountController.text.trim();
      if (text.isNotEmpty) {
        saleAmount = double.tryParse(text);
      }
    }
    final selection = VisitReasonSelection(
      reasonId: _selectedReason!.id,
      reasonName: _selectedReason!.name,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      saleAmount: saleAmount,
    );
    Navigator.pop(context, selection);
  }

  @override
  Widget build(BuildContext context) {
    final routeProv = context.watch<RouteProvider>();
    final reasons = routeProv.visitReasons;

    if (_selectedReason == null && reasons.isNotEmpty) {
      _selectedReason = reasons.first;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primaryStrong,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check-In Visit Reason',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Select a reason to proceed with location check-in',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: 16),

          // Main Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load visit reasons: $_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loadReasons,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryStrong,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else if (reasons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No visit reasons found on Odoo. Please create visit reasons in Odoo Configuration.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loadReasons,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryStrong,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Visit Reason Dropdown
            const Text(
              'Select Reason',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<VisitReason>(
              initialValue: reasons.contains(_selectedReason)
                  ? _selectedReason
                  : reasons.first,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.primaryStrong,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderSoft),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryStrong,
                    width: 1.8,
                  ),
                ),
              ),
              items: reasons.map((reason) {
                return DropdownMenuItem<VisitReason>(
                  value: reason,
                  child: Text(
                    reason.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedReason = val);
                }
              },
            ),
            if (_selectedReason?.isSale == true &&
                context.watch<AuthProvider>().canDo(AppAction.visitSaleAmount)) ...[
              const SizedBox(height: 16),
              const Text(
                'Sale Amount (৳)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _saleAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter sale amount...',
                  prefixIcon: const Icon(
                    Icons.payments_outlined,
                    color: AppColors.primaryStrong,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.primaryStrong,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Additional Notes Field
            const Text(
              'Notes / Remarks (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Enter any additional visit notes...',
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderSoft),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primaryStrong,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _selectedReason != null ? _confirm : null,
              icon: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Confirm & Check In',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                disabledBackgroundColor: AppColors.borderSoft,
                elevation: 3,
                shadowColor: const Color(0xFF059669).withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
