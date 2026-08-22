import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/employees/sales_employee.dart';
import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/features/employees/employee_provider.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class CreateSalesOfficerScreen extends StatefulWidget {
  const CreateSalesOfficerScreen({super.key, this.employee});

  final SalesEmployee? employee;

  @override
  State<CreateSalesOfficerScreen> createState() =>
      _CreateSalesOfficerScreenState();
}

class _CreateSalesOfficerScreenState extends State<CreateSalesOfficerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _routeSearchController = TextEditingController();

  DistributionHub? _selectedDistributor;
  final Set<int> _selectedRouteIds = {};
  List<Map<String, dynamic>> _routes = [];
  bool _loadingRoutes = false;

  bool get isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameController.text = widget.employee!.name;
      _phoneController.text = widget.employee!.mobilePhone ?? '';
      _emailController.text = widget.employee!.workEmail ?? '';
      _jobTitleController.text = widget.employee!.jobTitle ?? 'Sales Officer';
      if (widget.employee!.assignedRoutes != null) {
        for (var r in widget.employee!.assignedRoutes!) {
          if (r is Map && r['id'] != null) {
            _selectedRouteIds.add(r['id'] as int);
          }
        }
      }
    } else {
      _jobTitleController.text = 'Sales Officer';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final salesProvider = context.read<PrimarySaleProvider>();
      if (salesProvider.hubs.isEmpty) {
        await salesProvider.fetchInitialData();
      }

      if (isEdit && widget.employee!.distributor != null) {
        final distId = widget.employee!.distributor!['id'];
        try {
          _selectedDistributor = salesProvider.hubs.firstWhere(
            (h) => h.id == distId,
          );
        } catch (_) {
          // If not in hubs list, create a temp hub item
          _selectedDistributor = DistributionHub(
            id: distId,
            name:
                widget.employee!.distributor!['name'] ?? 'Unknown Distributor',
          );
        }
      }

      _loadRoutes();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _jobTitleController.dispose();
    _routeSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _loadingRoutes = true;
    });
    try {
      final loaded = await context.read<EmployeeProvider>().fetchRoutes(
        distributorId: _selectedDistributor?.id,
      );
      setState(() {
        _routes = loaded;
      });
    } catch (e) {
      // Fail silently or handle error
    } finally {
      setState(() {
        _loadingRoutes = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredRoutes {
    final query = _routeSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _routes;
    return _routes.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final code = (r['code'] ?? '').toString().toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDistributor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Distributor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final provider = context.read<EmployeeProvider>();
    SalesEmployee? result;

    if (isEdit) {
      result = await provider.updateEmployee(
        widget.employee!.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        distributorId: _selectedDistributor!.id,
        assignedRouteIds: _selectedRouteIds.toList(),
      );
    } else {
      result = await provider.createEmployee(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        distributorId: _selectedDistributor!.id,
        assignedRouteIds: _selectedRouteIds.toList(),
      );
    }

    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Sales Officer updated successfully'
                : 'Sales Officer created successfully',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save Sales Officer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<EmployeeProvider>().isLoading;
    final hubs = context.watch<PrimarySaleProvider>().hubs;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: isEdit ? 'Edit Sales Officer' : 'Create Sales Officer',
              subtitle: isEdit
                  ? 'Update details and route assignments'
                  : 'Register a new sales officer',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              trailing: ProfileAvatar(
                borderColor: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    _LabeledInput(
                      label: 'Sales Officer Name *',
                      hint: 'Enter full name',
                      controller: _nameController,
                      validator: _required,
                    ),
                    _LabeledInput(
                      label: 'Mobile Phone *',
                      hint: 'Enter mobile number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: _required,
                    ),
                    _LabeledInput(
                      label: 'Email Address',
                      hint: 'Enter email address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _LabeledInput(
                      label: 'Job Title',
                      hint: 'e.g. Sales Officer',
                      controller: _jobTitleController,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Distributor Tagging *',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<DistributionHub>(
                      initialValue: _selectedDistributor,
                      hint: const Text('Select Distributor'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE6F2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE6F2),
                          ),
                        ),
                      ),
                      items: hubs.map((hub) {
                        return DropdownMenuItem<DistributionHub>(
                          value: hub,
                          child: Text(hub.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedDistributor = val;
                          _selectedRouteIds.clear();
                        });
                        _loadRoutes();
                      },
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    _SelectionSection(
                      label:
                          'Assign Routes (${_selectedRouteIds.length} selected)',
                      searchHint: 'Search routes...',
                      searchController: _routeSearchController,
                      onSearchChanged: (_) => setState(() {}),
                      height: 220,
                      isLoading: _loadingRoutes,
                      children: _filteredRoutes.map((route) {
                        final id = route['id'] as int;
                        final selected = _selectedRouteIds.contains(id);
                        return _SelectableCard(
                          selected: selected,
                          title: route['name'] ?? '',
                          subtitle: route['code'] != null
                              ? 'Code: ${route['code']}'
                              : 'Route',
                          onTap: () => setState(() {
                            selected
                                ? _selectedRouteIds.remove(id)
                                : _selectedRouteIds.add(id);
                          }),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          color: Colors.white,
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryStrong,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isEdit ? 'Update Sales Officer' : 'Create Sales Officer',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  const _LabeledInput({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDDE6F2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDDE6F2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionSection extends StatelessWidget {
  const _SelectionSection({
    required this.label,
    required this.searchHint,
    required this.searchController,
    required this.onSearchChanged,
    required this.children,
    required this.height,
    this.isLoading = false,
  });

  final String label;
  final String searchHint;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> children;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: searchHint,
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDDE6F2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDDE6F2)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Scrollbar(
                  thumbVisibility: true,
                  child: ListView(
                    children: children.isEmpty
                        ? const [
                            Padding(
                              padding: EdgeInsets.all(18),
                              child: Center(
                                child: Text(
                                  'No routes available',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ]
                        : children,
                  ),
                ),
        ),
      ],
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.white,
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFDDE6F2),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }
}
