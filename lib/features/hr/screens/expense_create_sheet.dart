import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:secondary_sales/core/widgets/app_camera_capture_dialog.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/util/dialog_helper.dart';
import 'package:secondary_sales/features/hr/expense_provider.dart';

class ExpenseCreateSheet extends StatefulWidget {
  final ExpenseProvider provider;
  final Map<String, dynamic>? sheetToEdit;

  const ExpenseCreateSheet({super.key, required this.provider, this.sheetToEdit});

  static void show(BuildContext context, ExpenseProvider provider, {Map<String, dynamic>? sheetToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: provider,
        child: ExpenseCreateSheet(provider: provider, sheetToEdit: sheetToEdit),
      ),
    );
  }

  @override
  State<ExpenseCreateSheet> createState() => _ExpenseCreateSheetState();
}

class _ExpenseCreateSheetState extends State<ExpenseCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final List<Map<String, dynamic>> _expenseItems = [];

  String? _attachmentName;
  String? _attachmentBase64;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ExpenseProvider>();
      p.fetchCategories();
      p.fetchDrafts();
    });

    if (widget.sheetToEdit != null) {
      final sheet = widget.sheetToEdit!;
      if (sheet['description'] != null) {
        _descController.text = sheet['description'];
      }
      final List? expenses = sheet['expenses'];
      if (expenses != null && expenses.isNotEmpty) {
        for (var item in expenses) {
          _expenseItems.add({
            'id': item['id'],
            'title': item['title'] ?? item['category'] ?? '',
            'category_id': item['category_id'],
            'category_name': item['category'] ?? '',
            'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
            'date': item['date'] ?? DateTime.now().toString().split(' ')[0],
            'description': item['description'] ?? '',
            'odometer_day_start': (item['odometer_day_start'] as num?)?.toDouble(),
            'odometer_day_end': (item['odometer_day_end'] as num?)?.toDouble(),
            'total_km_run': (item['total_km_run'] as num?)?.toDouble(),
            'is_personal_vehicle': item['is_personal_vehicle'] == true,
            'expense_allowance_type': item['expense_allowance_type'] ?? '',
            'has_odometer_start_image': item['has_odometer_start_image'] == true,
            'has_odometer_end_image': item['has_odometer_end_image'] == true,
            'odometer_start_image': item['odometer_start_image'],
            'odometer_end_image': item['odometer_end_image'],
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
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
            category: MediaCategory.expenses,
          );
          final bytes = await (persistent ?? File(pickedFile.path!)).readAsBytes();
          base64Str = base64Encode(bytes);
        } else if (pickedFile.bytes != null) {
          final persistent = await MediaStorageService.persistBytes(
            pickedFile.bytes!,
            category: MediaCategory.expenses,
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
        showValidationErrorDialog(context, 'Error picking file: $e');
      }
    }
  }

  void _openAddItemDialog() {
    showDialog(
      context: context,
      // A tap outside would close the box and lose what was typed; close it
      // with Cancel instead.
      barrierDismissible: false,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: context.read<ExpenseProvider>(),
        child: _ExpenseItemDialog(
          onSave: (item) {
            setState(() {
              _expenseItems.add(item);
            });
          },
        ),
      ),
    );
  }

  void _openSelectDraftDialog() {
    final provider = context.read<ExpenseProvider>();
    final availableDrafts = provider.drafts.where((d) {
      final dId = d['id'];
      return !_expenseItems.any((item) => item['id'] == dId);
    }).toList();

    if (availableDrafts.isEmpty) {
      showValidationErrorDialog(
        context,
        'No pending vehicle trips or saved expenses found to add.',
        title: 'No Saved Trips or Expenses',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Saved Trip / Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: availableDrafts.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final draft = availableDrafts[index];
              final isPersonalVehicle = draft['is_personal_vehicle'] == true;
              final hasEndImage = draft['has_odometer_end_image'] == true;
              final title = draft['title'] ?? (isPersonalVehicle ? 'Personal Vehicle Trip' : 'Saved Expense');
              final amount = (draft['amount'] as num?)?.toDouble() ?? 0.0;
              final date = draft['date'] ?? '';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: isPersonalVehicle ? const Color(0xFF0D9488).withOpacity(0.12) : AppColors.primary.withOpacity(0.12),
                  child: Icon(
                    isPersonalVehicle ? Icons.two_wheeler_outlined : Icons.receipt_long_outlined,
                    color: isPersonalVehicle ? const Color(0xFF0D9488) : AppColors.primary,
                    size: 22,
                  ),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  isPersonalVehicle
                      ? 'Date: $date • KM: ${(draft['total_km_run'] ?? 0.0)} • End Photo: ${hasEndImage ? "✓" : "Missing ✕"}'
                      : 'Date: $date • Category: ${draft['category'] ?? ""}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '৳${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
                onTap: () {
                  if (isPersonalVehicle && !hasEndImage) {
                    Navigator.pop(ctx);
                    showValidationErrorDialog(
                      context,
                      'Day End Odometer Image is required for this trip before adding it to the expense report. Please complete the trip in the Personal Vehicle menu first.',
                      title: 'Missing Day End Photo',
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  setState(() {
                    _expenseItems.add({
                      'id': draft['id'],
                      'title': title,
                      'category_id': draft['category_id'],
                      'category_name': draft['category'] ?? '',
                      'amount': amount,
                      'date': date,
                      'description': draft['description'] ?? '',
                      'odometer_day_start': (draft['odometer_day_start'] as num?)?.toDouble(),
                      'odometer_day_end': (draft['odometer_day_end'] as num?)?.toDouble(),
                      'total_km_run': (draft['total_km_run'] as num?)?.toDouble(),
                      'is_personal_vehicle': isPersonalVehicle,
                      'expense_allowance_type': draft['expense_allowance_type'] ?? (isPersonalVehicle ? 'personal_vehicle_mileage_rate_card' : ''),
                      'has_odometer_start_image': draft['has_odometer_start_image'] == true,
                      'has_odometer_end_image': draft['has_odometer_end_image'] == true,
                    });
                  });
                },
              );
            },
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _expenseItems.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    final provider = context.read<ExpenseProvider>();
    if (provider.isSubmitting) return;

    if (_expenseItems.isEmpty) {
      showValidationErrorDialog(context, 'Please add at least one expense item.');
      return;
    }

    // Restriction check: Day Start & Day End meter photos are mandatory for Personal Vehicle items before adding to sheet
    for (var item in _expenseItems) {
      if (item['is_personal_vehicle'] == true) {
        final title = item['title'] ?? 'Personal Vehicle';
        final hasStart = item['has_odometer_start_image'] == true ||
            (item['odometer_start_image'] != null && (item['odometer_start_image'] as String).isNotEmpty);
        if (!hasStart) {
          showValidationErrorDialog(
            context,
            'Day Start Odometer Photo is required for "$title".',
          );
          return;
        }

        final hasEnd = item['has_odometer_end_image'] == true ||
            (item['odometer_end_image'] != null && (item['odometer_end_image'] as String).isNotEmpty);
        if (!hasEnd) {
          showValidationErrorDialog(
            context,
            'Day End Odometer Photo is mandatory for "$title" before submitting the report.',
          );
          return;
        }
      }
    }

    final bool isEditing = widget.sheetToEdit != null;
    final bool success = isEditing
        ? await provider.updateSheet(
            sheetId: widget.sheetToEdit!['id'],
            title: null,
            description: _descController.text.trim(),
            expenses: _expenseItems,
            attachment: _attachmentBase64,
            attachmentName: _attachmentName,
          )
        : await provider.createAndSubmitSheet(
            title: null,
            description: _descController.text.trim(),
            expenses: _expenseItems,
            attachment: _attachmentBase64,
            attachmentName: _attachmentName,
          );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Expense report updated successfully.' : 'Expense report created and submitted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted && provider.requestError != null) {
      showValidationErrorDialog(context, provider.requestError!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Matching Leave Request Sheet 1:1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expense Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Fill in the details for your expense report', style: TextStyle(color: Colors.grey)),
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

                // Description
                const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  enabled: !provider.isSubmitting,
                  decoration: InputDecoration(
                    hintText: 'Enter optional description for this report...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Attachment UI (Matching Leave Request Sheet 1:1)
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
                            _attachmentName ?? 'Select file (PDF, receipt image, doc...)',
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

                // Expense Items Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Expense Items *', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: provider.isSubmitting ? null : _openAddItemDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_expenseItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderSoft),
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.background,
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.post_add, size: 36, color: AppColors.textSecondary),
                          SizedBox(height: 6),
                          Text(
                            'No expense items added. Click "Add Item" to start.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: List.generate(_expenseItems.length, (index) {
                      final item = _expenseItems[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderSoft),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item['title'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              Text(
                                '৳${(item['amount'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Category: ${item['category_name']} • Date: ${item['date']}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                if (item['is_personal_vehicle'] == true ||
                                    (item['total_km_run'] != null && (item['total_km_run'] as num) > 0)) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      'Start: ${(item['odometer_day_start'] ?? 0.0).toStringAsFixed(1)} | End: ${(item['odometer_day_end'] ?? 0.0).toStringAsFixed(1)} | ${(item['total_km_run'] ?? 0.0).toStringAsFixed(1)} KM',
                                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          (item['has_odometer_start_image'] == true || item['odometer_start_image'] != null)
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          size: 13,
                                          color: (item['has_odometer_start_image'] == true || item['odometer_start_image'] != null)
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('Start Photo', style: TextStyle(fontSize: 11)),
                                        const SizedBox(width: 12),
                                        Icon(
                                          (item['has_odometer_end_image'] == true || item['odometer_end_image'] != null)
                                              ? Icons.check_circle
                                              : Icons.cancel,
                                          size: 13,
                                          color: (item['has_odometer_end_image'] == true || item['odometer_end_image'] != null)
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('End Photo', style: TextStyle(fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: provider.isSubmitting ? null : () => _removeItem(index),
                          ),
                        ),
                      );
                    }),
                  ),
                const SizedBox(height: 24),

                // Action Buttons Row (Matching Leave Request Sheet 1:1)
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
                        onPressed: provider.isSubmitting ? null : _submitReport,
                        child: provider.isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Submit Report'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseItemDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const _ExpenseItemDialog({required this.onSave});

  @override
  State<_ExpenseItemDialog> createState() => _ExpenseItemDialogState();
}

class _ExpenseItemDialogState extends State<_ExpenseItemDialog> {
  final _dialogFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _dayStartController = TextEditingController();
  final _dayEndController = TextEditingController();
  final _totalKmController = TextEditingController();

  File? _startPhotoFile;
  String? _startPhotoBase64;
  File? _endPhotoFile;
  String? _endPhotoBase64;

  Map<String, dynamic>? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickOdometerPhoto({required bool isStart}) async {
    try {
      final picked = await AppCameraCaptureDialog.capture(
        context,
        title: isStart ? 'Day Start Odometer Photo' : 'Day End Odometer Photo',
        helperTip: 'Align the vehicle odometer reading clearly within the frame',
      );
      if (picked == null) return;

      final persistentFile = await MediaStorageService.persistPickedFile(
        picked,
        category: MediaCategory.expenses,
        customPrefix: isStart ? 'odo_start' : 'odo_end',
      );
      final file = persistentFile ?? File(picked.path);
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);

      setState(() {
        if (isStart) {
          _startPhotoFile = file;
          _startPhotoBase64 = b64;
        } else {
          _endPhotoFile = file;
          _endPhotoBase64 = b64;
        }
      });
    } catch (e) {
      if (mounted) {
        showValidationErrorDialog(context, 'Failed to pick photo: $e');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descController.dispose();
    _dayStartController.dispose();
    _dayEndController.dispose();
    _totalKmController.dispose();
    super.dispose();
  }

  String get _allowanceType => _selectedCategory?['expense_allowance_type']?.toString() ?? '';
  bool get _isPersonalVehicle => _allowanceType == 'personal_vehicle_mileage_rate_card';
  bool get _isCeilingType => const [
    'ex_base_station_day_allowance',
    'night_stay_allowance',
    'hotel_ceiling_metro',
    'hotel_ceiling_non_metro',
  ].contains(_allowanceType);

  double? get _limitAmount => (_selectedCategory?['limit_amount'] as num?)?.toDouble();
  bool get _hasGrade => _selectedCategory?['has_grade'] == true;
  String get _gradeName => _selectedCategory?['grade_name']?.toString() ?? '';

  void _onOdometerChanged() {
    if (!_isPersonalVehicle) return;
    final startText = _dayStartController.text.trim();
    final endText = _dayEndController.text.trim();
    if (startText.isNotEmpty && endText.isNotEmpty) {
      final start = double.tryParse(startText) ?? 0.0;
      final end = double.tryParse(endText) ?? 0.0;
      if (end >= start) {
        final km = end - start;
        _totalKmController.text = km.toStringAsFixed(2);
        _recalculateMileageAmount(km);
      } else {
        _totalKmController.text = '0.00';
        _amountController.text = '0.00';
      }
    }
  }

  void _onTotalKmChanged() {
    if (!_isPersonalVehicle) return;
    final km = double.tryParse(_totalKmController.text.trim()) ?? 0.0;
    _recalculateMileageAmount(km);
  }

  void _recalculateMileageAmount(double km) {
    final rate = _limitAmount ?? 0.0;
    final total = km * rate;
    _amountController.text = total.toStringAsFixed(2);
  }

  void _onCategoryChanged(Map<String, dynamic>? val) {
    setState(() {
      _selectedCategory = val;
      if (_titleController.text.isEmpty && val != null) {
        _titleController.text = val['name'] ?? '';
      }
      if (_isPersonalVehicle) {
        _onOdometerChanged();
      } else {
        _amountController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Expense Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _dialogFormKey,
          // After a failed save, each error clears as soon as its field is
          // filled, not only on the next save.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category Product dropdown
                DropdownButtonFormField<Map<String, dynamic>>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Expense Category *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  initialValue: _selectedCategory,
                  items: provider.categories
                      .where((cat) => cat['expense_allowance_type'] != 'personal_vehicle_mileage_rate_card')
                      .map((cat) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: cat,
                      child: Text(cat['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: _onCategoryChanged,
                  validator: (val) => val == null ? 'Category is required.' : null,
                ),

                // Allowance type informative banner
                if (_selectedCategory != null && (_isCeilingType || _isPersonalVehicle)) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (!_hasGrade || _limitAmount == null)
                          ? Colors.amber.withOpacity(0.12)
                          : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (!_hasGrade || _limitAmount == null)
                            ? Colors.amber[700]!
                            : AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (!_hasGrade || _limitAmount == null) ? Icons.warning_amber_rounded : Icons.info_outline,
                          size: 18,
                          color: (!_hasGrade || _limitAmount == null) ? Colors.amber[800] : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            !_hasGrade
                                ? 'No employee grade assigned. This category requires an assigned grade.'
                                : _limitAmount == null
                                    ? 'This category is not configured in your grade (${_gradeName.isNotEmpty ? _gradeName : "Unassigned"}).'
                                    : _isPersonalVehicle
                                        ? 'Grade Rate: ৳${_limitAmount!.toStringAsFixed(2)} per km'
                                        : 'Grade Limit: Maximum ৳${_limitAmount!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (!_hasGrade || _limitAmount == null) ? Colors.amber[900] : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Item Title/Name
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title / Purpose *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Title is required.' : null,
                ),

                // Personal Vehicle Odometer and KM Fields
                if (_isPersonalVehicle) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _dayStartController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Day Start (Odo Meter) *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (_) => _onOdometerChanged(),
                          validator: (val) {
                            if (!_isPersonalVehicle) return null;
                            if (val == null || val.trim().isEmpty) return 'Required.';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _dayEndController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Day End (Odo Meter) *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (_) => _onOdometerChanged(),
                          validator: (val) {
                            if (!_isPersonalVehicle) return null;
                            if (val == null || val.trim().isEmpty) return 'Required.';
                            final startText = _dayStartController.text.trim();
                            final endText = _dayEndController.text.trim();
                            if (startText.isNotEmpty && endText.isNotEmpty) {
                              final start = double.tryParse(startText) ?? 0.0;
                              final end = double.tryParse(endText) ?? 0.0;
                              if (end < start) {
                                return 'Day End < Day Start.';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Odometer Photo Capture Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            side: BorderSide(
                              color: _startPhotoFile != null ? Colors.green : AppColors.primary,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _pickOdometerPhoto(isStart: true),
                          icon: Icon(
                            _startPhotoFile != null ? Icons.check_circle : Icons.photo_camera,
                            size: 16,
                            color: _startPhotoFile != null ? Colors.green : AppColors.primary,
                          ),
                          label: Text(
                            _startPhotoFile != null ? 'Start Photo ✓' : 'Start Photo *',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _startPhotoFile != null ? Colors.green : AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            side: BorderSide(
                              color: _endPhotoFile != null ? Colors.green : AppColors.primary,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _pickOdometerPhoto(isStart: false),
                          icon: Icon(
                            _endPhotoFile != null ? Icons.check_circle : Icons.photo_camera,
                            size: 16,
                            color: _endPhotoFile != null ? Colors.green : AppColors.primary,
                          ),
                          label: Text(
                            _endPhotoFile != null ? 'End Photo ✓' : 'End Photo *',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _endPhotoFile != null ? Colors.green : AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _totalKmController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Total Kilo Meter run *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      suffixText: 'KM',
                    ),
                    onChanged: (_) => _onTotalKmChanged(),
                    validator: (val) {
                      if (!_isPersonalVehicle) return null;
                      if (val == null || val.trim().isEmpty) return 'Total km is required.';
                      final km = double.tryParse(val.trim());
                      if (km == null || km <= 0) return 'Total km must be greater than 0.';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  readOnly: _isPersonalVehicle,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount (৳) *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    helperText: _isPersonalVehicle
                        ? (_limitAmount != null
                            ? 'Formula: Total KM × ৳${_limitAmount!.toStringAsFixed(2)}/km'
                            : null)
                        : (_isCeilingType && _limitAmount != null
                            ? 'Maximum allowed: ৳${_limitAmount!.toStringAsFixed(2)}'
                            : null),
                    helperMaxLines: 2,
                    filled: _isPersonalVehicle,
                    fillColor: _isPersonalVehicle ? Colors.grey[100] : null,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Amount is required.';
                    final d = double.tryParse(val.trim());
                    if (d == null || d <= 0) return 'Enter a valid amount > 0.';
                    if (_isCeilingType) {
                      if (!_hasGrade) {
                        return 'Cannot submit: No grade assigned to employee.';
                      }
                      if (_limitAmount == null) {
                        return 'Cannot submit: Category not configured in your grade.';
                      }
                      if (d > _limitAmount!) {
                        return 'Amount exceeds maximum allowed limit of ৳${_limitAmount!.toStringAsFixed(2)}.';
                      }
                    } else if (_isPersonalVehicle) {
                      if (!_hasGrade) {
                        return 'Cannot submit: No grade assigned to employee.';
                      }
                      if (_limitAmount == null) {
                        return 'Cannot submit: Personal vehicle rate is not configured in your grade.';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date Picker
                InkWell(
                  onTap: () async {
                    final dt = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (dt != null) {
                      setState(() {
                        _selectedDate = dt;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Expense Date *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_selectedDate.toLocal().toString().split(' ')[0], style: const TextStyle(fontSize: 13)),
                        const Icon(Icons.calendar_today, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Item Description
                TextFormField(
                  controller: _descController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          onPressed: () {
            if (_dialogFormKey.currentState?.validate() ?? false) {
              final allowanceType = _allowanceType;
              final isPersonalVehicle = _isPersonalVehicle;

              if (isPersonalVehicle) {
                if (_startPhotoBase64 == null) {
                  showValidationErrorDialog(
                    context,
                    'Day Start Odometer Photo is required for Personal Vehicle.',
                  );
                  return;
                }
                if (_endPhotoBase64 == null) {
                  showValidationErrorDialog(
                    context,
                    'Day End Odometer Photo is required for Personal Vehicle.',
                  );
                  return;
                }
              }

              final startKm = isPersonalVehicle ? (double.tryParse(_dayStartController.text.trim()) ?? 0.0) : null;
              final endKm = isPersonalVehicle ? (double.tryParse(_dayEndController.text.trim()) ?? 0.0) : null;
              final totalKm = isPersonalVehicle ? (double.tryParse(_totalKmController.text.trim()) ?? 0.0) : null;

              final Map<String, dynamic> item = {
                'title': _titleController.text.trim(),
                'amount': double.parse(_amountController.text.trim()),
                'category_id': _selectedCategory!['id'],
                'category_name': _selectedCategory!['name'],
                'date': _selectedDate.toLocal().toString().split(' ')[0],
                'description': _descController.text.trim(),
                'expense_allowance_type': allowanceType,
                'is_personal_vehicle': isPersonalVehicle,
                if (startKm != null) 'odometer_day_start': startKm,
                if (endKm != null) 'odometer_day_end': endKm,
                if (totalKm != null) 'total_km_run': totalKm,
                if (isPersonalVehicle) 'odometer_start_image': _startPhotoBase64,
                if (isPersonalVehicle) 'has_odometer_start_image': _startPhotoBase64 != null,
                if (isPersonalVehicle) 'odometer_end_image': _endPhotoBase64,
                if (isPersonalVehicle) 'has_odometer_end_image': _endPhotoBase64 != null,
              };

              widget.onSave(item);
              Navigator.pop(context);
            }
          },
          child: const Text('Save Item'),
        ),
      ],
    );
  }
}
