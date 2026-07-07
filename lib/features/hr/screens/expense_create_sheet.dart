import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().fetchCategories();
      context.read<ExpenseProvider>().fetchDrafts();
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
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
    if (_expenseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one expense item.')),
      );
      return;
    }

    final provider = context.read<ExpenseProvider>();
    final success = await provider.createAndSubmitSheet(
      title: null,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      expenses: _expenseItems,
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense report created and submitted successfully.')),
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

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Pull bar
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title block
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'New Expense Report',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),

              // Form content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 8),

                      // Description
                      TextFormField(
                        controller: _descController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'Optional description of the sheet...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // Added items header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Expense Lines',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                            onPressed: _openAddItemDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_expenseItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderSoft),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.post_add, size: 40, color: AppColors.textSecondary),
                                SizedBox(height: 8),
                                Text(
                                  'No items added. Click "Add Item" to start.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(_expenseItems.length, (index) {
                          final item = _expenseItems[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.borderSoft),
                            ),
                            elevation: 0,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Category: ${item['category_name']} • Date: ${item['date']}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removeItem(index),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Bottom Submission action button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: provider.isSubmitting ? null : _submitReport,
                    child: provider.isSubmitting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
  
  bool _isNewItem = true;
  Map<String, dynamic>? _selectedDraft;
  Map<String, dynamic>? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return AlertDialog(
      title: const Text('Add Expense Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _dialogFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selection type toggler
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Create New')),
                        selected: _isNewItem,
                        onSelected: (val) {
                          setState(() {
                            _isNewItem = true;
                            _selectedDraft = null;
                            _titleController.clear();
                            _amountController.clear();
                            _descController.clear();
                            _selectedCategory = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Select Expense')),
                        selected: !_isNewItem,
                        onSelected: (val) {
                          setState(() {
                            _isNewItem = false;
                            _selectedDraft = null;
                            _titleController.clear();
                            _amountController.clear();
                            _descController.clear();
                            _selectedCategory = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!_isNewItem) ...[
                  // Drafts dropdown
                  DropdownButtonFormField<Map<String, dynamic>>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Expense',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedDraft,
                    items: provider.drafts.map((draft) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: draft,
                        child: Text('${draft['title']} (৳${draft['amount']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDraft = val;
                        if (val != null) {
                          _titleController.text = val['title'] ?? '';
                          _amountController.text = val['amount']?.toString() ?? '';
                          _descController.text = val['description'] ?? '';
                          _selectedDate = DateTime.tryParse(val['date'] ?? '') ?? DateTime.now();
                          // Pre-select category
                          final catId = val['category_id'];
                          if (catId != null) {
                            try {
                              _selectedCategory = provider.categories.firstWhere((c) => c['id'] == catId);
                            } catch (_) {
                              _selectedCategory = null;
                            }
                          }
                        }
                      });
                    },
                    validator: (val) => val == null ? 'Draft selection is required.' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Category Product dropdown
                DropdownButtonFormField<Map<String, dynamic>>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Expense Category',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCategory,
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
                  decoration: const InputDecoration(labelText: 'Title / Purpose', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Title is required.' : null,
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (৳)', border: OutlineInputBorder()),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Amount is required.';
                    final d = double.tryParse(val.trim());
                    if (d == null || d <= 0) return 'Enter a valid amount > 0.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date Picker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
                    OutlinedButton(
                      onPressed: () async {
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
                      child: const Text('Change Date'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Item Description
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Item Description', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
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

              if (!_isNewItem && _selectedDraft != null) {
                // Attach the Odoo record ID so backend knows it's an existing draft
                item['id'] = _selectedDraft!['id'];
              }

              widget.onSave(item);
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
