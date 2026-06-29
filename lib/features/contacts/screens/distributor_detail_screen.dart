import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/features/employees/employee_provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class DistributorDetailScreen extends StatefulWidget {
  const DistributorDetailScreen({super.key, required this.distributor});

  final DistributionHub distributor;

  @override
  State<DistributorDetailScreen> createState() =>
      _DistributorDetailScreenState();
}

class _DistributorDetailScreenState extends State<DistributorDetailScreen> {
  late DistributionHub _distributor;

  @override
  void initState() {
    super.initState();
    _distributor = widget.distributor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().fetchEmployees(
        distributorId: _distributor.id,
      );
    });
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'SO';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final employeeProvider = context.watch<EmployeeProvider>();
    final assignedSOs = employeeProvider.employees;
    final isSOLoading = employeeProvider.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: _distributor.name,
              subtitle: 'Dealer profile and staff details',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.section),
                children: [
                  // Dealer Info Panel
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: ssPanelDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Information',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: 'Dealer Name',
                          value: _distributor.name,
                        ),
                        _DetailRow(
                          label: 'Mobile / Phone',
                          value: _distributor.mobile ?? _distributor.phone,
                        ),
                        _DetailRow(label: 'Email', value: _distributor.email),
                        _DetailRow(
                          label: 'Address',
                          value: _distributor.street,
                        ),
                        _DetailRow(label: 'Zip Code', value: _distributor.zip),
                        if (_distributor.vat != null &&
                            _distributor.vat!.isNotEmpty)
                          _DetailRow(
                            label: 'VAT Number',
                            value: _distributor.vat,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Assigned Sales Officers Panel
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: ssPanelDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Sales Officers',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isSOLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (assignedSOs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No Sales Officers assigned to this dealer.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: assignedSOs.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 20,
                              color: AppColors.borderMuted,
                            ),
                            itemBuilder: (context, index) {
                              final so = assignedSOs[index];
                              return Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.primarySoft,
                                    child: Text(
                                      _getInitials(so.name),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          so.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          so.jobTitle ?? 'Sales Officer',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (so.mobilePhone != null)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.phone_outlined,
                                        size: 20,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () {
                                        // Optional: Call action
                                      },
                                    ),
                                ],
                              );
                            },
                          ),
                      ],
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
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value == null || value!.trim().isEmpty ? '-' : value!,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
