import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/util/dialog_helper.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/hr/expense_provider.dart';

class PersonalVehicleTripDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> trip;

  const PersonalVehicleTripDetailsSheet({super.key, required this.trip});

  static Future<String?> show(
    BuildContext context,
    Map<String, dynamic> trip, {
    ExpenseProvider? provider,
  }) {
    final expenseProvider = provider ?? context.read<ExpenseProvider>();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: expenseProvider,
        child: PersonalVehicleTripDetailsSheet(trip: trip),
      ),
    );
  }

  Color _getStatusColor(bool hasSheet, bool isCompleted) {
    if (hasSheet) return Colors.green;
    if (isCompleted) return Colors.blue[800]!;
    return Colors.amber[800]!;
  }

  Color _getStatusBgColor(bool hasSheet, bool isCompleted) {
    return _getStatusColor(hasSheet, isCompleted).withOpacity(0.12);
  }

  Future<void> _createExpenseSheet(BuildContext context, int expenseId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Expense Sheet', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Create and submit an Expense Sheet for "$title"? It will be sent to your manager for approval.'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create & Submit'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final provider = context.read<ExpenseProvider>();
    final result = await provider.submitVehicleExpenseSheet(expenseId: expenseId);

    if (result != null && context.mounted) {
      Navigator.pop(context); // Close bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense Sheet "${result['sheet_title']}" created and submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (context.mounted && provider.requestError != null) {
      showValidationErrorDialog(context, provider.requestError!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    final title = trip['title'] ?? 'Personal Vehicle Travel';
    final date = trip['date'] ?? '';
    final amount = (trip['amount'] as num?)?.toDouble() ?? 0.0;
    final totalKm = (trip['total_km_run'] as num?)?.toDouble() ?? 0.0;
    final startKm = (trip['odometer_day_start'] as num?)?.toDouble() ?? 0.0;
    final endKm = (trip['odometer_day_end'] as num?)?.toDouble() ?? 0.0;
    final hasSheet = trip['sheet_id'] != null;
    final sheetTitle = trip['sheet_title'] ?? '';
    final isCompleted = endKm > 0 && trip['has_odometer_end_image'] == true;
    final description = trip['description']?.toString() ?? '';
    final startImgUrl = trip['odometer_start_image_url']?.toString();
    final endImgUrl = trip['odometer_end_image_url']?.toString();
    final authProvider = context.read<AuthProvider>();
    final baseUrl = authProvider.baseUrl;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (date.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Trip Date: $date',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(hasSheet, isCompleted),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hasSheet
                          ? 'Sheet: $sheetTitle'
                          : isCompleted
                              ? 'Completed (Unreported)'
                              : 'In Progress',
                      style: TextStyle(
                        color: _getStatusColor(hasSheet, isCompleted),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Total Distance', '${totalKm.toStringAsFixed(2)} KM'),
                        const SizedBox(height: 8),
                        _buildInfoRow('Total Amount', '৳${amount.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        _buildInfoRow('Day Start Meter', '${startKm.toStringAsFixed(1)} KM'),
                        const SizedBox(height: 8),
                        _buildInfoRow('Day End Meter', isCompleted ? '${endKm.toStringAsFixed(1)} KM' : 'Not recorded yet'),
                        if (hasSheet && sheetTitle.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow('Expense Sheet', sheetTitle),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildInfoRow('Remarks', description),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Odometer Photos Section
                  const Text(
                    'Odometer Photos',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Start Image
                      Expanded(
                        child: _buildImageTile(
                          title: 'Day Start Meter',
                          hasImage: trip['has_odometer_start_image'] == true,
                          imageUrl: (startImgUrl != null && startImgUrl.isNotEmpty) ? '$baseUrl$startImgUrl' : null,
                          headers: authProvider.authHeaders,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // End Image
                      Expanded(
                        child: _buildImageTile(
                          title: 'Day End Meter',
                          hasImage: trip['has_odometer_end_image'] == true,
                          imageUrl: (endImgUrl != null && endImgUrl.isNotEmpty) ? '$baseUrl$endImgUrl' : null,
                          headers: authProvider.authHeaders,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),

            // Actions footer
            if (!hasSheet && !isCompleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context, 'complete'),
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text(
                      'Finish Trip (Record End Meter)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
            if (!hasSheet && isCompleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: provider.isSubmitting
                        ? null
                        : () => _createExpenseSheet(context, trip['id'], title),
                    icon: provider.isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.post_add),
                    label: Text(
                      provider.isSubmitting ? 'Creating Sheet...' : 'Create & Submit Expense Sheet',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile({
    required String title,
    required bool hasImage,
    required String? imageUrl,
    required Map<String, String> headers,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: hasImage && imageUrl != null
                  ? Image.network(
                      imageUrl,
                      headers: headers,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 32, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('Photo Captured ✓', style: TextStyle(fontSize: 11, color: Colors.green)),
                          ],
                        ),
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hide_image_outlined, size: 32, color: Colors.grey),
                          SizedBox(height: 4),
                          Text('No Photo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
