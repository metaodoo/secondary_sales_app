import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/hr/leave_provider.dart';

class LeaveDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> leave;

  const LeaveDetailsSheet({super.key, required this.leave});

  static void show(BuildContext context, LeaveProvider provider, Map<String, dynamic> leave) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: LeaveDetailsSheet(leave: leave),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaveProvider>();
    final bool canApprove = leave['can_approve'] ?? false;
    final String status = leave['status'] ?? '';
    
    // Status Badge Logic
    Color badgeColor = Colors.grey;
    String badgeText = status.toUpperCase();
    if (status == 'confirm') {
      badgeColor = Colors.orange;
      badgeText = 'TO APPROVE';
    } else if (status == 'validate') {
      badgeColor = Colors.green;
      badgeText = 'APPROVED';
    } else if (status == 'refuse') {
      badgeColor = Colors.red;
      badgeText = 'REJECTED';
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48), // balance space
                    const Text('Leave Request Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Employee Information Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.borderSoft),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Employee Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        _buildDetailRow('Employee Name', leave['employee_name'] ?? '-'),
                        const SizedBox(height: 8),
                        _buildDetailRow('Department', leave['department'] ?? '-'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Leave Information Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.borderSoft),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Leave Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        _buildDetailRow('Reference ID', leave['reference_id'] ?? '-'),
                        const SizedBox(height: 8),
                        _buildDetailRow('Leave Type', leave['leave_type'] ?? '-'),
                        const SizedBox(height: 8),
                        _buildDetailRow('Start Date', leave['date_from'] ?? '-'),
                        const SizedBox(height: 8),
                        _buildDetailRow('End Date', leave['date_to'] ?? '-'),
                        const SizedBox(height: 8),
                        _buildDetailRow('Duration', leave['duration'] ?? '-'),
                        const SizedBox(height: 8),
                        _buildDetailRow('Applied On', leave['applied_on'] ?? '-'),
                        const SizedBox(height: 8),
                        _buildDetailRow('Pending Approver', leave['pending_approver'] ?? '-'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reason
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.borderSoft),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reason', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          (leave['reason'] == null || leave['reason'].isEmpty) ? '-' : leave['reason'],
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.red)),
                ),

              // Action Buttons
              if (canApprove)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successSoft,
                            foregroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: provider.isActionLoading ? null : () async {
                            final success = await provider.submitLeaveAction(leave['leave_id'], 'approve');
                            if (success && context.mounted) Navigator.pop(context);
                          },
                          child: provider.isActionLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2))
                              : const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dangerSoft,
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: provider.isActionLoading ? null : () async {
                            final success = await provider.submitLeaveAction(leave['leave_id'], 'reject');
                            if (success && context.mounted) Navigator.pop(context);
                          },
                          child: provider.isActionLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
                              : const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ),
                
               if (!canApprove)
                  const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
