import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/hr/expense_provider.dart';

class ExpenseCreateSheet extends StatefulWidget {
  final ExpenseProvider provider;

  const ExpenseCreateSheet({super.key, required this.provider});

  static void show(BuildContext context, ExpenseProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: provider,
        child: ExpenseCreateSheet(provider: provider),
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
      context.read<ExpenseProvider>().fetchCategories();
    });
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
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String? base64Str;

        if (file.bytes != null) {
          base64Str = base64Encode(file.bytes!);
        } else if (file.path != null) {
          final bytes = await File(file.path!).readAsBytes();
          base64Str = base64Encode(bytes);
        }

        if (base64Str != null) {
          setState(() {
            _attachmentName = file.name;
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

  void _openAddItemDialog() {
    showDialog(
      context: context,
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

  void _removeItem(int index) {
    setState(() {
      _expenseItems.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    final provider = context.read<ExpenseProvider>();
    if (provider.isSubmitting) return;

    if (_expenseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one expense item.')),
      );
      return;
    }

    final success = await provider.createAndSubmitSheet(
      title: null,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      expenses: _expenseItems,
      attachment: _attachmentBase64,
      attachmentName: _attachmentName,
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense report created and submitted successfully.'), backgroundColor: Colors.green),
      );
    } else if (mounted && provider.requestError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.requestError!)),
      );
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
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      onPressed: provider.isSubmitting ? null : _openAddItemDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            child: Text(
                              'Category: ${item['category_name']} • Date: ${item['date']}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                          trailing: IconButton(
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
  
  Map<String, dynamic>? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

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
                  items: provider.categories.map((cat) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: cat,
                      child: Text(cat['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  },
                  validator: (val) => val == null ? 'Category is required.' : null,
                ),
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
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount (৳) *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Amount is required.';
                    final d = double.tryParse(val.trim());
                    if (d == null || d <= 0) return 'Enter a valid amount > 0.';
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
              final Map<String, dynamic> item = {
                'title': _titleController.text.trim(),
                'amount': double.parse(_amountController.text.trim()),
                'category_id': _selectedCategory!['id'],
                'category_name': _selectedCategory!['name'],
                'date': _selectedDate.toLocal().toString().split(' ')[0],
                'description': _descController.text.trim(),
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
