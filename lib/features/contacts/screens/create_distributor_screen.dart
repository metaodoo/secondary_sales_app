import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class CreateDistributorScreen extends StatefulWidget {
  const CreateDistributorScreen({super.key, this.distributor});

  final DistributionHub? distributor;

  @override
  State<CreateDistributorScreen> createState() =>
      _CreateDistributorScreenState();
}

class _CreateDistributorScreenState extends State<CreateDistributorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipController = TextEditingController();

  bool get isEdit => widget.distributor != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameController.text = widget.distributor!.name;
      _phoneController.text =
          widget.distributor!.mobile ?? widget.distributor!.phone ?? '';
      _emailController.text = widget.distributor!.email ?? '';
      _addressController.text = widget.distributor!.street ?? '';
      _zipController.text = widget.distributor!.zip ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<PrimarySaleProvider>();
    DistributionHub? result;

    if (isEdit) {
      result = await provider.updateDistributor(
        widget.distributor!.id,
        name: _nameController.text.trim(),
        mobile: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        street: _addressController.text.trim(),
        zip: _zipController.text.trim(),
      );
    } else {
      result = await provider.createDistributor(
        name: _nameController.text.trim(),
        mobile: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        street: _addressController.text.trim(),
        zip: _zipController.text.trim(),
      );
    }

    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Dealer updated successfully'
                : 'Dealer created successfully',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save dealer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<PrimarySaleProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: isEdit ? 'Edit Dealer' : 'Add New Dealer',
              subtitle: isEdit
                  ? 'Modify details of this dealer'
                  : 'Register a new distributor partner',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              trailing: const Icon(Icons.grid_view, color: Colors.white70),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSoft),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LabeledInput(
                            label: 'Dealer Name *',
                            hint: 'Enter dealer name',
                            controller: _nameController,
                            validator: _required,
                          ),
                          _LabeledInput(
                            label: 'Phone *',
                            hint: 'Enter phone number',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: _required,
                          ),
                          _LabeledInput(
                            label: 'Email',
                            hint: 'dealer@example.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _LabeledInput(
                            label: 'Address *',
                            hint: 'Enter full business address',
                            controller: _addressController,
                            validator: _required,
                          ),
                          _LabeledInput(
                            label: 'Zip Code',
                            hint: '00000',
                            controller: _zipController,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isEdit ? 'Update Dealer' : 'Save Dealer',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: Colors.white,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
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
              color: Color(0xFF334155),
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
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primaryStrong,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
