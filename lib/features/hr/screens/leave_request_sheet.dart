import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/hr/leave_provider.dart';

class LeaveRequestSheet extends StatefulWidget {
  const LeaveRequestSheet({super.key});

  static void show(BuildContext context, LeaveProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const LeaveRequestSheet(),
      ),
    );
  }

  @override
  State<LeaveRequestSheet> createState() => _LeaveRequestSheetState();
}

class _LeaveRequestSheetState extends State<LeaveRequestSheet> {
  int? _selectedLeaveTypeId;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _reasonController = TextEditingController();

  String? _attachmentName;
  String? _attachmentBase64;
  bool _validationTriggered = false;

  void _submit() async {
    setState(() {
      _validationTriggered = true;
    });

    if (_selectedLeaveTypeId == null ||
        _startDate == null ||
        _endDate == null ||
        _reasonController.text.trim().isEmpty) {
      return;
    }

    final provider = context.read<LeaveProvider>();
    final success = await provider.submitLeaveRequest(
      leaveTypeId: _selectedLeaveTypeId!,
      dateFrom: _startDate!.toString().split(' ')[0],
      dateTo: _endDate!.toString().split(' ')[0],
      reason: _reasonController.text.trim(),
      attachment: _attachmentBase64,
      attachmentName: _attachmentName,
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request submitted successfully'), backgroundColor: Colors.green));
    } else if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Validation Error'),
            ],
          ),
          content: Text(provider.requestError ?? 'Failed to submit request.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  void _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _attachmentName = file.name;
            _attachmentBase64 = base64Encode(file.bytes!);
          });
        } else if (file.path != null) {
          final bytes = await File(file.path!).readAsBytes();
          setState(() {
            _attachmentName = file.name;
            _attachmentBase64 = base64Encode(bytes);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LeaveProvider>();
    
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Request Leave', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Fill in the details for your leave request', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Form Fields
              const Text('Leave Type *', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (provider.isLoadingTypes)
                const Center(child: CircularProgressIndicator())
              else if (provider.leaveTypes.isEmpty)
                const Text('No leave types available', style: TextStyle(color: Colors.red))
              else
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    errorText: (_validationTriggered && _selectedLeaveTypeId == null)
                        ? 'Leave type is required'
                        : null,
                  ),
                  hint: const Text('Select leave type'),
                  value: _selectedLeaveTypeId,
                  isExpanded: true,
                  items: provider.leaveTypes.map((type) {
                    return DropdownMenuItem<int>(
                      value: type['id'],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              type['name'], 
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (type['requires_allocation'] == 'yes'
                                      ? type['is_available'] == true
                                      : true)
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              type['requires_allocation'] == 'yes'
                                  ? (type['remaining'] != null
                                      ? (double.tryParse(type['remaining'].toString()) ?? 0.0) % 1 == 0
                                          ? (double.tryParse(type['remaining'].toString()) ?? 0.0).toInt().toString()
                                          : type['remaining'].toString()
                                      : '0')
                                  : 'Available',
                              style: TextStyle(
                                color: (type['requires_allocation'] == 'yes'
                                        ? type['is_available'] == true
                                        : true)
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: provider.isSubmitting ? null : (val) => setState(() => _selectedLeaveTypeId = val),
                ),
              const SizedBox(height: 16),

              const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: provider.isSubmitting ? null : () => _pickDate(true),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Date *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          errorText: (_validationTriggered && _startDate == null)
                              ? 'Required'
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _startDate != null ? _startDate!.toString().split(' ')[0] : 'Select date',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.calendar_today, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: provider.isSubmitting ? null : () => _pickDate(false),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Date *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          errorText: (_validationTriggered && _endDate == null)
                              ? 'Required'
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _endDate != null ? _endDate!.toString().split(' ')[0] : 'Select date',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.calendar_today, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Reason *', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                enabled: !provider.isSubmitting,
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Enter reason for leave...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  errorText: (_validationTriggered && _reasonController.text.trim().isEmpty)
                      ? 'Reason is required'
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Attachment UI
              const Text('Attachment (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: provider.isSubmitting ? null : _pickAttachment,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderSoft),
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.background,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _attachmentName != null ? Icons.file_present : Icons.upload_file,
                        color: _attachmentName != null ? AppColors.primary : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _attachmentName ?? 'Select file (PDF, image, doc...)',
                          style: TextStyle(
                            color: _attachmentName != null ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_attachmentName != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.red),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: provider.isSubmitting
                              ? null
                              : () => setState(() {
                                    _attachmentName = null;
                                    _attachmentBase64 = null;
                                  }),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),


                
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: provider.isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: provider.isSubmitting ? null : _submit,
                      child: provider.isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Submit Request'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
