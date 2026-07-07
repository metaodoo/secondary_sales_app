import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/hr/expense_provider.dart';

class ExpenseDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> sheetSummary;

  const ExpenseDetailsSheet({super.key, required this.sheetSummary});

  static void show(BuildContext context, Map<String, dynamic> sheetSummary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: context.read<ExpenseProvider>(),
        child: ExpenseDetailsSheet(sheetSummary: sheetSummary),
      ),
    );
  }

  @override
  State<ExpenseDetailsSheet> createState() => _ExpenseDetailsSheetState();
}

class _ExpenseDetailsSheetState extends State<ExpenseDetailsSheet> {
  final TextEditingController _refuseReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().fetchSheetDetails(widget.sheetSummary['id']);
    });
  }

  @override
  void dispose() {
    _refuseReasonController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approve':
      case 'approved':
      case 'post':
      case 'done':
        return Colors.green;
      case 'submit':
      case 'submitted':
        return Colors.blue;
      case 'cancel':
      case 'refused':
        return Colors.red;
      case 'draft':
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBgColor(String status) {
    return _getStatusColor(status).withOpacity(0.1);
  }

  void _showRefuseDialog(BuildContext context, ExpenseProvider provider, int sheetId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuse Expense Report'),
        content: TextField(
          controller: _refuseReasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for refusal',
            hintText: 'Enter reason...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = _refuseReasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason for refusal.')),
                );
                return;
              }
              Navigator.pop(ctx);
              final success = await provider.refuseSheet(sheetId, reason);
              if (success && context.mounted) {
                Navigator.pop(context); // Close details sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense report refused successfully.')),
                );
              } else if (context.mounted && provider.actionError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(provider.actionError!)),
                );
              }
            },
            child: const Text('Refuse'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final isPendingMode = provider.activeTab == 'pending';
    final sheetId = widget.sheetSummary['id'];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Pull bar
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title block
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.sheetSummary['title'] ?? 'Expense Report',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Report Date: ${widget.sheetSummary['date']}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusBgColor(widget.sheetSummary['status']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.sheetSummary['status_label'] ?? 'DRAFT',
                        style: TextStyle(
                          color: _getStatusColor(widget.sheetSummary['status']),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),

              // Content block
              Expanded(
                child: provider.isLoadingDetails
                    ? const Center(child: CircularProgressIndicator())
                    : provider.selectedSheetDetails == null
                        ? Center(
                            child: Text(
                              provider.errorMessage ?? 'Failed to load details.',
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              // Info card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    _buildInfoRow('Employee', provider.selectedSheetDetails!['employee_name'] ?? ''),
                                    const SizedBox(height: 8),
                                    _buildInfoRow('Total Amount', '৳${(provider.selectedSheetDetails!['amount'] as double).toStringAsFixed(2)}'),
                                    if (provider.selectedSheetDetails!['description'] != null &&
                                        provider.selectedSheetDetails!['description'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildInfoRow('Description', provider.selectedSheetDetails!['description']),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              const Text(
                                'Expense Items',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 12),

                              // Expense items list
                              ...List.generate(
                                (provider.selectedSheetDetails!['expenses'] as List).length,
                                (index) {
                                  final item = provider.selectedSheetDetails!['expenses'][index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: AppColors.borderSoft),
                                    ),
                                    elevation: 0,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item['category'] ?? '',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                              ),
                                              Text(
                                                '৳${(item['amount'] as double).toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item['title'] ?? '',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Date: ${item['date']}',
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                          if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                                            const Divider(height: 16),
                                            Text(
                                              item['description'],
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
              ),

              // Actions footer
              if (provider.selectedSheetDetails != null &&
                  provider.selectedSheetDetails!['can_approve'] == true) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _showRefuseDialog(context, provider, sheetId),
                          child: const Text('Refuse', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final success = await provider.approveSheet(sheetId);
                            if (success && context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Expense report approved successfully.')),
                              );
                            } else if (context.mounted && provider.actionError != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(provider.actionError!)),
                              );
                            }
                          },
                          child: provider.isActionLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
