import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/hr/attendance_provider.dart';
import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';

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

/// Checks if the user is actively checked in for today.
/// If not checked in, displays a popup restriction dialog explaining that
/// daily attendance is mandatory for operational actions (Van Load, Order Entry, Outlet Visits),
/// with a direct button to navigate to the Attendance Screen.
/// Returns `true` if attendance is active, `false` otherwise.
Future<bool> checkAttendanceRestriction(
  BuildContext context, {
  required String actionName,
}) async {
  final attendanceProv = Provider.of<AttendanceProvider>(context, listen: false);
  if (attendanceProv.isCheckedIn) {
    return true;
  }

  // Refresh status from server in case local state was not loaded yet
  await attendanceProv.refresh();
  if (attendanceProv.isCheckedIn) {
    return true;
  }

  if (!context.mounted) return false;

  await showDialog<void>(
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
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.access_time_filled_rounded,
                color: Colors.amber.shade800,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Attendance Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Daily attendance is mandatory before executing operational actions ($actionName). Please log in (Check In) for today first.',
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AttendanceScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStrong,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Check In Now',
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
  return false;
}


