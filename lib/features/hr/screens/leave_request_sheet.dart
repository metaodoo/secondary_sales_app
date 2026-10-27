import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/hr/leave_provider.dart';

class LeaveRequestSheet extends StatefulWidget {
  final Map<String, dynamic>? leaveToEdit;

  const LeaveRequestSheet({super.key, this.leaveToEdit});

  static void show(BuildContext context, LeaveProvider provider, {Map<String, dynamic>? leaveToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: LeaveRequestSheet(leaveToEdit: leaveToEdit),
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

  @override
  void initState() {
    super.initState();
    if (widget.leaveToEdit != null) {
      final leave = widget.leaveToEdit!;
      _selectedLeaveTypeId = leave['leave_type_id'];
      if (leave['date_from'] != null) {
        _startDate = DateTime.tryParse(leave['date_from']);
      }
      if (leave['date_to'] != null) {
        _endDate = DateTime.tryParse(leave['date_to']);
      }
      if (leave['reason'] != null) {
        _reasonController.text = leave['reason'];
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LeaveProvider>();
      if (provider.leaveTypes.isEmpty && !provider.isLoadingTypes) {
        provider.fetchLeaveTypes();
      }
    });
  }

  Map<String, dynamic>? get _selectedLeaveType {
    if (_selectedLeaveTypeId == null) return null;
    final provider = context.read<LeaveProvider>();
    try {
      return provider.leaveTypes.firstWhere((t) => t['id'] == _selectedLeaveTypeId);
    } catch (_) {
      return null;
    }
  }

  bool get _isSickLeave {
    final type = _selectedLeaveType;
    if (type == null) return false;
    return type['is_sick_leave'] == true;
  }

  bool get _isCasualLeave {
    final type = _selectedLeaveType;
    if (type == null) return false;
    return type['is_casual_leave'] == true;
  }

  bool get _allowConsecutiveDays {
    final type = _selectedLeaveType;
    if (type == null) return true;
    return type['allow_consecutive_days'] != false;
  }

  bool get _isMaternityLeave {
    final type = _selectedLeaveType;
    if (type == null) return false;
    return type['is_maternity_leave'] == true;
  }

  double get _maxDaysPerMonth {
    final type = _selectedLeaveType;
    if (type == null) return 0.0;
    return (type['max_days_per_month'] as num?)?.toDouble() ?? 0.0;
  }

  double? get _currentMonthRemainingQuota {
    final type = _selectedLeaveType;
    if (type == null) return null;
    return (type['current_month_remaining_quota'] as num?)?.toDouble();
  }

  int get _durationDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  bool get _requiresAttachment {
    return _isSickLeave && _durationDays > 2;
  }

  bool get _requiresAdvanceNotice {
    final type = _selectedLeaveType;
    if (type == null) return false;
    return type['requires_advance_notice'] == true;
  }

  int get _advanceNoticeDays {
    final type = _selectedLeaveType;
    if (type == null) return 7;
    final val = type['advance_notice_days'];
    if (val is int) return val;
    return int.tryParse(val?.toString() ?? '') ?? 7;
  }

  void _onLeaveTypeChanged(int? newTypeId) {
    setState(() {
      _selectedLeaveTypeId = newTypeId;
      final selectedType = _selectedLeaveType;
      final policy = (selectedType != null ? (selectedType['date_policy'] ?? 'any') : 'any').toString();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (_requiresAdvanceNotice) {
        final earliest = today.add(Duration(days: _advanceNoticeDays));
        if (_startDate != null && _startDate!.isBefore(earliest)) {
          _startDate = earliest;
        }
        if (_endDate != null && _endDate!.isBefore(earliest)) {
          _endDate = earliest;
        }
      }

      if (_isCasualLeave || !_allowConsecutiveDays) {
        if (_startDate != null) {
          _endDate = _startDate;
        }
      }

      if (policy == 'past_today') {
        if (_startDate != null && _startDate!.isAfter(today)) _startDate = null;
        if (_endDate != null && _endDate!.isAfter(today)) _endDate = null;
      } else if (policy == 'today_only') {
        if (_startDate != null && (_startDate!.year != today.year || _startDate!.month != today.month || _startDate!.day != today.day)) {
          _startDate = today;
        }
        if (_endDate != null && (_endDate!.year != today.year || _endDate!.month != today.month || _endDate!.day != today.day)) {
          _endDate = today;
        }
      }
    });
  }

  void _showRestrictionDialog(
    String title,
    String message, {
    IconData icon = Icons.info_outline,
    Color iconColor = const Color(0xFFD97706),
    Color iconBgColor = const Color(0xFFFEF3C7),
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _submit() async {
    final provider = context.read<LeaveProvider>();
    if (provider.isSubmitting) return;

    setState(() {
      _validationTriggered = true;
    });

    // 1. Validate Leave Type
    if (_selectedLeaveTypeId == null) {
      _showRestrictionDialog(
        'Leave Type Required',
        'Please select a leave type before submitting your request.',
        icon: Icons.category_outlined,
        iconColor: const Color(0xFFDC2626),
        iconBgColor: const Color(0xFFFEE2E2),
      );
      return;
    }

    // 2. Validate Start Date
    if (_startDate == null) {
      _showRestrictionDialog(
        'Start Date Required',
        'Please select the start date for your leave request.',
        icon: Icons.calendar_today_outlined,
        iconColor: const Color(0xFFDC2626),
        iconBgColor: const Color(0xFFFEE2E2),
      );
      return;
    }

    // 3. Validate End Date
    if (_endDate == null) {
      _showRestrictionDialog(
        'End Date Required',
        'Please select the end date for your leave request.',
        icon: Icons.calendar_today_outlined,
        iconColor: const Color(0xFFDC2626),
        iconBgColor: const Color(0xFFFEE2E2),
      );
      return;
    }

    // 4. Validate Date Order
    if (_endDate!.isBefore(_startDate!)) {
      _showRestrictionDialog(
        'Invalid Date Range',
        'End date cannot be earlier than start date. Please select a valid date range.',
        icon: Icons.date_range_outlined,
        iconColor: const Color(0xFFDC2626),
        iconBgColor: const Color(0xFFFEE2E2),
      );
      return;
    }

    // Casual Leave / Non-consecutive single-day restriction
    if ((_isCasualLeave || !_allowConsecutiveDays) && _durationDays > 1) {
      final typeName = _selectedLeaveType?['name'] ?? 'Casual Leave';
      _showRestrictionDialog(
        'Single-Day Policy',
        '$typeName can only be requested for 1 day at a time. Consecutive days are not permitted under company policy.',
        icon: Icons.event_busy_outlined,
        iconColor: const Color(0xFFD97706),
        iconBgColor: const Color(0xFFFEF3C7),
      );
      return;
    }

    // 7. Monthly Quota Restriction
    if (_isCasualLeave && _currentMonthRemainingQuota != null && _currentMonthRemainingQuota! <= 0) {
      final typeName = _selectedLeaveType?['name'] ?? 'Casual Leave';
      final maxQuota = _maxDaysPerMonth > 0 ? _maxDaysPerMonth.toInt() : 2;
      _showRestrictionDialog(
        'Monthly Quota Exhausted',
        'Your monthly quota for $typeName is exhausted (Maximum $maxQuota day(s) per calendar month). You cannot submit additional requests for this month.',
        icon: Icons.block_outlined,
        iconColor: const Color(0xFFDC2626),
        iconBgColor: const Color(0xFFFEE2E2),
      );
      return;
    }

    // 8. Mandatory Sick Leave Attachment (> 2 days)
    if (_requiresAttachment && (_attachmentBase64 == null || _attachmentBase64!.isEmpty) && widget.leaveToEdit == null) {
      _showRestrictionDialog(
        'Medical Document Required',
        'For Sick Leave exceeding 2 days, attaching a medical certificate, prescription, or relevant document is mandatory.',
        icon: Icons.attach_file_outlined,
        iconColor: const Color(0xFFD97706),
        iconBgColor: const Color(0xFFFEF3C7),
      );
      return;
    }

    // 9. Advance Notice Restriction
    if (_requiresAdvanceNotice && _startDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final noticeDays = start.difference(today).inDays;
      if (noticeDays < _advanceNoticeDays) {
        final leaveTypeName = _selectedLeaveType?['name'] ?? 'This leave type';
        final earliestDate = today.add(Duration(days: _advanceNoticeDays));
        final formattedEarliest = '${earliestDate.year}-${earliestDate.month.toString().padLeft(2, '0')}-${earliestDate.day.toString().padLeft(2, '0')}';
        _showRestrictionDialog(
          'Advance Notice Required',
          '$leaveTypeName must be requested at least $_advanceNoticeDays calendar day(s) in advance.\n\nEarliest selectable start date is $formattedEarliest (Current notice given: ${noticeDays < 0 ? 0 : noticeDays} day(s)).',
          icon: Icons.schedule_outlined,
          iconColor: const Color(0xFFD97706),
          iconBgColor: const Color(0xFFFEF3C7),
        );
        return;
      }
    }

    final bool isEditing = widget.leaveToEdit != null;
    final bool success = isEditing
        ? await provider.updateLeaveRequest(
            leaveId: widget.leaveToEdit!['leave_id'],
            leaveTypeId: _selectedLeaveTypeId,
            dateFrom: _startDate!.toString().split(' ')[0],
            dateTo: _endDate!.toString().split(' ')[0],
            reason: _reasonController.text.trim(),
            attachment: _attachmentBase64,
            attachmentName: _attachmentName,
          )
        : await provider.submitLeaveRequest(
            leaveTypeId: _selectedLeaveTypeId!,
            dateFrom: _startDate!.toString().split(' ')[0],
            dateTo: _endDate!.toString().split(' ')[0],
            reason: _reasonController.text.trim(),
            attachment: _attachmentBase64,
            attachmentName: _attachmentName,
          );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Leave request updated successfully' : 'Leave request submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Leave Policy Requirement',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text(
              provider.requestError ?? 'Could not submit your leave request. Please check date selections.',
              style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Understand & Adjust Dates', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final policy = (_selectedLeaveType != null ? (_selectedLeaveType!['date_policy'] ?? 'any') : 'any').toString();

    DateTime firstDate = today.subtract(const Duration(days: 90));
    DateTime lastDate = today.add(const Duration(days: 365));

    if (_requiresAdvanceNotice) {
      firstDate = today.add(Duration(days: _advanceNoticeDays));
    }

    if (policy == 'past_today') {
      lastDate = today;
    } else if (policy == 'today_only') {
      firstDate = today;
      lastDate = today;
    }

    DateTime initialDate = isStart
        ? (_startDate ?? (_requiresAdvanceNotice ? firstDate : today))
        : (_endDate ?? _startDate ?? (_requiresAdvanceNotice ? firstDate : today));

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }
    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_isCasualLeave || !_allowConsecutiveDays) {
            _endDate = picked;
          } else if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          if (_isCasualLeave || !_allowConsecutiveDays) {
            _startDate = picked;
            _endDate = picked;
          } else {
            _endDate = picked;
            if (_startDate != null && _startDate!.isAfter(_endDate!)) {
              _startDate = _endDate;
            }
          }
        }
      });
    }
  }

  void _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        String? base64Str;

        if (pickedFile.path != null) {
          final persistent = await MediaStorageService.persistFile(
            File(pickedFile.path!),
            category: MediaCategory.documents,
          );
          final bytes = await (persistent ?? File(pickedFile.path!)).readAsBytes();
          base64Str = base64Encode(bytes);
        } else if (pickedFile.bytes != null) {
          final persistent = await MediaStorageService.persistBytes(
            pickedFile.bytes!,
            category: MediaCategory.documents,
            originalFileName: pickedFile.name,
          );
          final bytes = persistent != null
              ? await persistent.readAsBytes()
              : pickedFile.bytes!;
          base64Str = base64Encode(bytes);
        }

        if (base64Str != null) {
          setState(() {
            _attachmentName = pickedFile.name;
            _attachmentBase64 = base64Str;
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
                    tooltip: 'Close',
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
                              (type['is_casual_leave'] == true && type['current_month_remaining_quota'] != null)
                                  ? '${(type['current_month_remaining_quota'] as num).toInt()}/${(type['max_days_per_month'] as num?)?.toInt() ?? 2} left/mo'
                                  : (type['requires_allocation'] == 'yes'
                                      ? (type['remaining'] != null
                                          ? (double.tryParse(type['remaining'].toString()) ?? 0.0) % 1 == 0
                                              ? (double.tryParse(type['remaining'].toString()) ?? 0.0).toInt().toString()
                                              : type['remaining'].toString()
                                          : '0')
                                      : 'Available'),
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
                  onChanged: provider.isSubmitting ? null : _onLeaveTypeChanged,
                ),
              if (_isCasualLeave) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Casual Leave (CL): Single-day requests only. Max 2 days/month${_currentMonthRemainingQuota != null ? ' (${_currentMonthRemainingQuota!.toInt()} of ${_maxDaysPerMonth.toInt()} days left this month).' : '.'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_requiresAdvanceNotice) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF3B82F6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Advance Notice: Must be submitted at least $_advanceNoticeDays calendar days in advance.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E40AF),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_isMaternityLeave) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEC4899)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.child_care, color: Color(0xFFDB2777), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Maternity Leave (ML): Continuous calendar days. Weekends and public holidays are included in duration.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9D174D),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                      onTap: (_isCasualLeave || !_allowConsecutiveDays || provider.isSubmitting)
                          ? null
                          : () => _pickDate(false),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Date *',
                          helperText: (_isCasualLeave || !_allowConsecutiveDays) ? 'Single day' : null,
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
                                style: TextStyle(
                                  fontSize: 13,
                                  color: (_isCasualLeave || !_allowConsecutiveDays)
                                      ? AppColors.textSecondary
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              (_isCasualLeave || !_allowConsecutiveDays) ? Icons.lock_outline : Icons.calendar_today,
                              size: 16,
                              color: (_isCasualLeave || !_allowConsecutiveDays) ? Colors.grey : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Reason (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                enabled: !provider.isSubmitting,
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Enter reason for leave...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              if (_requiresAttachment) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'For Sick Leave of more than 2 days, attaching a photo or document is mandatory.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Attachment UI
              Text(
                _requiresAttachment ? 'Attachment (Mandatory) *' : 'Attachment (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _requiresAttachment ? Colors.red.shade700 : null,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: provider.isSubmitting ? null : _pickAttachment,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: (_validationTriggered && _requiresAttachment && (_attachmentBase64 == null || _attachmentBase64!.isEmpty))
                          ? Colors.red
                          : AppColors.borderSoft,
                      width: (_validationTriggered && _requiresAttachment && (_attachmentBase64 == null || _attachmentBase64!.isEmpty)) ? 1.5 : 1.0,
                    ),
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
                          tooltip: 'Close',
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
