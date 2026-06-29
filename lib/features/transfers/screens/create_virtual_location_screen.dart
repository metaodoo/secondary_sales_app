import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/features/transfers/transfer_provider.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/data/models/employees/sales_employee.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class CreateVirtualLocationScreen extends StatefulWidget {
  const CreateVirtualLocationScreen({super.key});

  @override
  State<CreateVirtualLocationScreen> createState() =>
      _CreateVirtualLocationScreenState();
}

class _CreateVirtualLocationScreenState
    extends State<CreateVirtualLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  DistributionHub? _selectedHub;
  SalesEmployee? _selectedEmployee;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrimarySaleProvider>().fetchInitialData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHub == null || _selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select distributor and employee')),
      );
      return;
    }

    final loc = await context.read<TransferProvider>().createVirtualLocation(
      name: _nameController.text.trim(),
      assignedEmployeeId: _selectedEmployee!.id,
      assignedDistributorId: _selectedHub!.id,
    );

    if (!mounted) return;
    if (loc != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Virtual location created successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context, true);
    } else {
      final error = context.read<TransferProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to create location'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<TransferProvider>();
    final primaryProvider = context.watch<PrimarySaleProvider>();
    final isLoading = inventoryProvider.isLoading || primaryProvider.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: 'Create Virtual Location',
              subtitle: 'Assign van loading location',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Location Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: ssInputDecoration(
                        'Van Loading Location Name',
                        Icons.edit_location,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Distributor',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<DistributionHub>(
                      initialValue: _selectedHub,
                      isExpanded: true,
                      decoration: ssInputDecoration(
                        'Select Distributor',
                        Icons.business,
                      ),
                      items: primaryProvider.hubs.map((hub) {
                        return DropdownMenuItem(
                          value: hub,
                          child: Text(hub.name),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedHub = v;
                          _selectedEmployee = null;
                        });
                        if (v == null) {
                          context.read<TransferProvider>().clearEmployees();
                        } else {
                          context.read<TransferProvider>().fetchEmployees(
                            distributorId: v.id,
                          );
                        }
                      },
                      validator: (v) =>
                          v == null ? 'Distributor is required' : null,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Assigned Employee',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<SalesEmployee>(
                      initialValue: _selectedEmployee,
                      isExpanded: true,
                      decoration: ssInputDecoration(
                        _selectedHub == null
                            ? 'Select distributor first'
                            : 'Select Employee',
                        Icons.person,
                      ),
                      selectedItemBuilder: (context) {
                        return inventoryProvider.employees.map((employee) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              employee.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList();
                      },
                      items: inventoryProvider.employees.map((employee) {
                        return DropdownMenuItem(
                          value: employee,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(employee.name),
                              Text(
                                employee.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _selectedHub == null
                          ? null
                          : (v) => setState(() => _selectedEmployee = v),
                      validator: (v) =>
                          v == null ? 'Employee is required' : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Create Van Loading Location',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
