import 'dart:async';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/employees/sales_employee.dart';
import 'package:secondary_sales/features/employees/employee_provider.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/employees/screens/create_sales_officer_screen.dart';
import 'package:secondary_sales/features/employees/screens/sales_officer_detail_screen.dart';

class SalesOfficerListScreen extends StatefulWidget {
  const SalesOfficerListScreen({super.key});

  @override
  State<SalesOfficerListScreen> createState() => _SalesOfficerListScreenState();
}

class _SalesOfficerListScreenState extends State<SalesOfficerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().fetchEmployees();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      context.read<EmployeeProvider>().fetchEmployees(search: value);
    });
  }

  Future<void> _openCreateSO() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateSalesOfficerScreen()),
    );
    if (created == true && mounted) {
      context.read<EmployeeProvider>().fetchEmployees(
        search: _searchController.text,
      );
    }
  }

  Future<void> _openSODetail(SalesEmployee employee) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SalesOfficerDetailScreen(employeeId: employee.id),
      ),
    );
    if (updated == true && mounted) {
      context.read<EmployeeProvider>().fetchEmployees(
        search: _searchController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sales Officers',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: const ProfileAvatar(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      floatingActionButton:
          context.watch<AuthProvider>().canDo(AppAction.employeeCreate)
              ? SsCreateFab(label: 'New Sales Officer', onPressed: _openCreateSO)
              : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<EmployeeProvider>().fetchEmployees(
            search: _searchController.text,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, kSsFabScrollPadding),
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search sales officer...',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 24),
              if (provider.error != null) ErrorPanel(provider.error!),
              if (provider.isLoading && provider.employees.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
              if (provider.isLoading && provider.employees.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.employees.isEmpty)
                const EmptyPanel(message: 'No sales officers found')
              else
                ...provider.employees.map(
                  (employee) => _SalesOfficerCard(
                    employee: employee,
                    onTap: () => _openSODetail(employee),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesOfficerCard extends StatelessWidget {
  const _SalesOfficerCard({required this.employee, required this.onTap});

  final SalesEmployee employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (employee.mobilePhone != null &&
                          employee.mobilePhone!.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              employee.mobilePhone!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (employee.workEmail != null &&
                          employee.workEmail!.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.email,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              employee.workEmail!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (employee.distributor != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'DB: ${employee.distributor!['name']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.borderSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
