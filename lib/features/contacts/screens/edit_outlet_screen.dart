import 'package:flutter/material.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/data/models/contacts/outlet_class.dart';
import 'package:secondary_sales/data/models/contacts/outlet_type.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/core/util/dialog_helper.dart';

class EditOutletScreen extends StatefulWidget {
  final Map<String, dynamic> outlet;

  const EditOutletScreen({super.key, required this.outlet});

  @override
  State<EditOutletScreen> createState() => _EditOutletScreenState();
}

class _EditOutletScreenState extends State<EditOutletScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  int? _selectedOutletClassId;
  int? _selectedOutletTypeId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.outlet['name']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text:
          widget.outlet['mobile']?.toString() ??
          widget.outlet['phone']?.toString() ??
          '',
    );
    _addressController = TextEditingController(
      text: widget.outlet['street']?.toString() ?? '',
    );

    int? classId;
    final rawClassId = widget.outlet['outlet_class_id'];
    if (rawClassId is int) {
      classId = rawClassId;
    } else if (widget.outlet['outlet_class'] is Map) {
      classId = widget.outlet['outlet_class']['id'] as int?;
    }

    int? typeId;
    final rawTypeId = widget.outlet['outlet_type_id'];
    if (rawTypeId is int) {
      typeId = rawTypeId;
    } else if (widget.outlet['outlet_type'] is Map) {
      typeId = widget.outlet['outlet_type']['id'] as int?;
    }

    _selectedOutletClassId = classId;
    _selectedOutletTypeId = typeId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RouteProvider>(context, listen: false);
      provider.fetchOutletClasses();
      provider.fetchOutletTypes();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveOutlet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = Provider.of<RouteProvider>(context, listen: false);

    try {
      final updatedOutlet = await provider.updateOutlet(
        widget.outlet['id'] as int,
        name: _nameController.text.trim(),
        mobile: _phoneController.text.trim(),
        street: _addressController.text.trim(),
        outletClassId: _selectedOutletClassId,
        outletTypeId: _selectedOutletTypeId,
      );

      setState(() => _isSaving = false);

      if (!mounted) return;

      if (updatedOutlet != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Outlet updated successfully')),
        );
        Navigator.pop(context, true);
      } else {
        await showValidationErrorDialog(
          context,
          provider.error ?? 'Failed to update outlet',
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        await showValidationErrorDialog(context, e.toString());
      }
    }
  }

  bool _isArchiving = false;

  Future<void> _archiveOutlet() async {
    final outletId = widget.outlet['id'] as int?;
    final outletName = widget.outlet['name']?.toString() ?? 'this outlet';
    if (outletId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Outlet'),
        content: Text('Are you sure you want to archive "$outletName"? It will no longer be available for visits or routes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isArchiving = true);

    try {
      final routeProv = context.read<RouteProvider>();
      final success = await routeProv.archiveOutlet(
        outletId,
        activeRouteId: routeProv.activeRoute?.id,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Outlet "$outletName" archived successfully.')),
        );
        Navigator.pop(context, true);
      } else {
        final error = routeProv.error;
        showValidationErrorDialog(
          context,
          error ?? 'Failed to archive outlet.',
          title: 'Archive Failed',
        );
      }
    } catch (e) {
      if (!mounted) return;
      showValidationErrorDialog(
        context,
        e.toString().replaceAll('Exception: ', ''),
        title: 'Archive Error',
      );
    } finally {
      if (mounted) setState(() => _isArchiving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Outlet',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ProfileAvatar(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Outlet Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Modify the name, phone, or address of this outlet.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OUTLET DETAILS',
                      style: TextStyle(
                        color: AppColors.primaryStrong,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Customer Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter customer name'
                          : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.borderMuted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer<RouteProvider>(
                      builder: (context, provider, _) {
                        final availableClasses = List<OutletClass>.from(provider.outletClasses);
                        if (_selectedOutletClassId != null &&
                            !availableClasses.any((c) => c.id == _selectedOutletClassId)) {
                          String initialName = 'Class #$_selectedOutletClassId';
                          if (widget.outlet['outlet_class'] is Map) {
                            initialName = widget.outlet['outlet_class']['name']?.toString() ?? initialName;
                          }
                          availableClasses.insert(0, OutletClass(id: _selectedOutletClassId!, name: initialName));
                        }

                        final availableTypes = List<OutletType>.from(provider.outletTypes);
                        if (_selectedOutletTypeId != null &&
                            !availableTypes.any((t) => t.id == _selectedOutletTypeId)) {
                          String initialName = 'Type #$_selectedOutletTypeId';
                          if (widget.outlet['outlet_type'] is Map) {
                            initialName = widget.outlet['outlet_type']['name']?.toString() ?? initialName;
                          }
                          availableTypes.insert(0, OutletType(id: _selectedOutletTypeId!, name: initialName));
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Outlet Class *',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int>(
                                    value: _selectedOutletClassId,
                                    validator: (val) => val == null
                                        ? 'Outlet Class is required'
                                        : null,
                                    decoration: InputDecoration(
                                      hintText: availableClasses.isEmpty
                                          ? 'No classes found'
                                          : 'Select Class',
                                      filled: true,
                                      fillColor: AppColors.borderMuted,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    items: availableClasses.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c.id,
                                        child: Text(c.name),
                                      );
                                    }).toList(),
                                    onChanged: availableClasses.isEmpty
                                        ? null
                                        : (val) {
                                            setState(() => _selectedOutletClassId = val);
                                          },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Outlet Type *',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int>(
                                    value: _selectedOutletTypeId,
                                    validator: (val) => val == null
                                        ? 'Outlet Type is required'
                                        : null,
                                    decoration: InputDecoration(
                                      hintText: availableTypes.isEmpty
                                          ? 'No types found'
                                          : 'Select Type',
                                      filled: true,
                                      fillColor: AppColors.borderMuted,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    items: availableTypes.map((t) {
                                      return DropdownMenuItem<int>(
                                        value: t.id,
                                        child: Text(t.name),
                                      );
                                    }).toList(),
                                    onChanged: availableTypes.isEmpty
                                        ? null
                                        : (val) {
                                            setState(() => _selectedOutletTypeId = val);
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: AppColors.borderSoft),
                    const SizedBox(height: 24),
                    const Text(
                      'CONTACT INFORMATION',
                      style: TextStyle(
                        color: AppColors.primaryStrong,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Enter mobile number',
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Address',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Street name, building, floor...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: AppColors.background),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _isSaving ? null : _saveOutlet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryStrong,
                disabledBackgroundColor: AppColors.borderSoft,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Update Outlet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: (_isSaving || _isArchiving) ? null : _archiveOutlet,
              icon: _isArchiving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Color(0xFFDC2626),
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.archive_outlined, size: 18),
              label: Text(_isArchiving ? 'Archiving...' : 'Archive Outlet'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
