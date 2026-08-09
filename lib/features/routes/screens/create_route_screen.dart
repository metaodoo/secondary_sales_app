import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/routes/route.dart';
import 'package:secondary_sales/data/models/employees/sales_employee.dart';
import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/features/employees/employee_provider.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class CreateRouteScreen extends StatefulWidget {
  final RouteModel? route;

  const CreateRouteScreen({super.key, this.route});

  @override
  State<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends State<CreateRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  DistributionHub? _selectedDealer;
  final List<SalesEmployee> _selectedEmployees = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final saleProvider = context.read<PrimarySaleProvider>();
      final empProvider = context.read<EmployeeProvider>();

      if (saleProvider.hubs.isEmpty) {
        await saleProvider.fetchInitialData();
      }
      if (empProvider.employees.isEmpty) {
        await empProvider.fetchEmployees();
      }

      _initializeData();
    });
  }

  void _initializeData() {
    if (widget.route != null) {
      _nameController.text = widget.route!.name;

      // Initialize selected dealer
      if (widget.route!.distributorId != null) {
        final hubs = context.read<PrimarySaleProvider>().hubs;
        final idx = hubs.indexWhere((h) => h.id == widget.route!.distributorId);
        if (idx != -1) {
          setState(() {
            _selectedDealer = hubs[idx];
          });
        }
      }

      // Initialize selected employees
      final allEmps = context.read<EmployeeProvider>().employees;
      final assignedIds = widget.route!.employees.map((e) => e.id).toSet();
      setState(() {
        _selectedEmployees.clear();
        for (var emp in allEmps) {
          if (assignedIds.contains(emp.id)) {
            _selectedEmployees.add(emp);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showEmployeeSearchSelector() {
    final empProvider = context.read<EmployeeProvider>();
    final availableEmps = empProvider.employees.where((emp) {
      return !_selectedEmployees.any((selected) => selected.id == emp.id);
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final filteredList = availableEmps.where((emp) {
              return emp.name.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Sales Officers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: ssInputDecoration(
                      'Search sales officer...',
                      Icons.search,
                    ),
                    onChanged: (val) {
                      setStateSheet(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredList.isEmpty
                        ? const Center(
                            child: Text(
                              'No available sales officers found.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final emp = filteredList[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primarySoft,
                                  child: Text(
                                    emp.name.isNotEmpty
                                        ? emp.name[0].toUpperCase()
                                        : 'S',
                                    style: const TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  emp.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(emp.jobTitle ?? 'Sales Officer'),
                                trailing: const Icon(
                                  Icons.add_circle_outline,
                                  color: AppColors.primaryStrong,
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedEmployees.add(emp);
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveRoute() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDealer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a primary dealer.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final distributorId = _selectedDealer!.id;
      final employeeIds = _selectedEmployees.map((e) => e.id).toList();

      RouteModel? result;
      if (widget.route == null) {
        result = await context.read<RouteProvider>().createRoute(
          name: name,
          distributorId: distributorId,
          employeeIds: employeeIds,
        );
      } else {
        result = await context.read<RouteProvider>().updateRoute(
          widget.route!.id,
          name: name,
          distributorId: distributorId,
          employeeIds: employeeIds,
          active: widget.route!.active,
        );
      }

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.route == null
                  ? 'Route created successfully!'
                  : 'Route updated successfully!',
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        if (mounted) {
          final err = context.read<RouteProvider>().error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err ?? 'Failed to save route')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hubs = context.watch<PrimarySaleProvider>().hubs;
    final allEmployeesCount = context
        .watch<EmployeeProvider>()
        .employees
        .length;
    final availableCount = allEmployeesCount - _selectedEmployees.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.route == null ? 'Create Route' : 'Edit Route',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION: ROUTE DETAILS
                _buildSectionTitle(Icons.alt_route, 'ROUTE DETAILS'),
                const SizedBox(height: 12),
                const Text(
                  'Route Name',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: ssInputDecoration(
                    'e.g. Northwest Corridor Alpha',
                    Icons.abc,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Route name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 24),

                // SECTION: DEALER ASSIGNMENT
                _buildSectionTitle(
                  Icons.storefront_outlined,
                  'DEALER ASSIGNMENT',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Primary Dealer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<DistributionHub>(
                  decoration: ssInputDecoration(
                    'Select a authorized dealer',
                    Icons.arrow_drop_down,
                  ),
                  value: _selectedDealer,
                  items: hubs.map((hub) {
                    return DropdownMenuItem<DistributionHub>(
                      value: hub,
                      child: Text(hub.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDealer = val;
                    });
                  },
                  validator: (val) {
                    if (val == null) {
                      return 'Please select a primary dealer';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // SECTION: ASSIGN SALES OFFICERS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle(
                      Icons.assignment_ind_outlined,
                      'ASSIGN SALES OFFICERS',
                    ),
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
                        '$availableCount Available',
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _showEmployeeSearchSelector,
                  child: AbsorbPointer(
                    child: TextField(
                      decoration: ssInputDecoration(
                        'Search and add Sales Officers...',
                        Icons.search,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.borderMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _selectedEmployees.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text(
                              'No Sales Officers assigned yet.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: _selectedEmployees.map((emp) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.borderSoft),
                              ),
                              child: ListTile(
                                title: Text(
                                  emp.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFEF4444),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedEmployees.removeWhere(
                                        (e) => e.id == emp.id,
                                      );
                                    });
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveRoute,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryStrong,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save),
          label: Text(
            widget.route == null ? 'Save Route' : 'Update Route',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textPrimary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
