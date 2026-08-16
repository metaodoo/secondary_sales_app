import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

/// Shows a clean validation error popup dialog and logs the error to console.
Future<void> showValidationErrorDialog(
  BuildContext context,
  String rawErrorMessage, {
  String title = 'Validation Error',
}) async {
  var cleanMessage = rawErrorMessage
      .replaceAll('Exception: ', '')
      .replaceAll('Odoo Server Error', '')
      .trim();

  if (cleanMessage.startsWith(':')) {
    cleanMessage = cleanMessage.substring(1).trim();
  }

  if (cleanMessage.isEmpty) {
    cleanMessage = 'A validation error occurred. Please check your inputs.';
  }

  // Log validation error cleanly to console for diagnostics
  debugPrint('[ValidationError] $cleanMessage');

  if (!context.mounted) return;

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          cleanMessage,
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStrong,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}
