import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

class MtVisitReasonDialog extends StatefulWidget {
  const MtVisitReasonDialog({super.key});

  /// Displays the Modern Trade check-out reason bottom sheet.
  /// Returns the mandatory text reason if confirmed, or null if cancelled.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MtVisitReasonDialog(),
    );
  }

  @override
  State<MtVisitReasonDialog> createState() => _MtVisitReasonDialogState();
}

class _MtVisitReasonDialogState extends State<MtVisitReasonDialog> {
  final TextEditingController _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _notesController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a reason before checking out.';
      });
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: bottomInset + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
                      Icons.assignment_late_outlined,
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
                          'Check-Out Reason',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Modern Trade Visit',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.borderSoft),
              const SizedBox(height: 16),

              // Informational Notice Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No sales order or stock audit was submitted during this visit. A text explanation is required to complete check-out.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF92400E),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Reason Input Label
              RichText(
                text: const TextSpan(
                  text: 'Reason for Check-Out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Text Area
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                maxLength: 300,
                autofocus: true,
                onChanged: (val) {
                  if (_errorMessage != null && val.trim().isNotEmpty) {
                    setState(() => _errorMessage = null);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Enter reason for zero order / audit (e.g., store manager unavailable, stock count deferred)...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _errorMessage != null ? Colors.red : AppColors.borderSoft,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _errorMessage != null ? Colors.red : AppColors.borderSoft,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _errorMessage != null ? Colors.red : AppColors.primaryStrong,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.borderSoft),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryStrong,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _confirm,
                      child: const Text(
                        'Confirm Check-Out',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
