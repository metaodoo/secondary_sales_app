import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
import 'package:secondary_sales/core/widgets/app_camera_capture_dialog.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

class IsReturnScreen extends StatefulWidget {
  const IsReturnScreen({super.key, required this.category, required this.title});

  final String category;
  final String title;

  @override
  State<IsReturnScreen> createState() => _IsReturnScreenState();
}

class _IsReturnScreenState extends State<IsReturnScreen> {
  final ApiService _api = ApiService.instance;
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _returns = [];
  bool _loading = true;
  String? _error;
  String _state = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getIsReturns(
        category: widget.category,
        state: _state,
        search: _search.text.trim(),
      );
      final rows = data['returns'];
      if (!mounted) return;
      setState(() {
        _returns = rows is List ? rows.map((row) => Map<String, dynamic>.from(row as Map)).toList() : [];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const stages = [
      ('all', 'All'),
      ('executive', 'Executive'),
      ('dm', 'Delivery Man'),
      ('coordinator', 'Coordinator'),
      ('sales_operation', 'Sales Ops'),
      ('completed', 'Completed'),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => IsReturnCreateScreen(category: widget.category, title: widget.title),
            ),
          );
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search return or customer'),
              onSubmitted: (_) => _load(),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final stage in stages)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(stage.$2),
                      selected: _state == stage.$1,
                      onSelected: (_) {
                        setState(() => _state = stage.$1);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: _returns.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final row = _returns[index];
                            final partner = row['partner'] is Map ? Map<String, dynamic>.from(row['partner'] as Map) : <String, dynamic>{};
                            return Card(
                              child: ListTile(
                                title: Text('${row['name'] ?? ''}'),
                                subtitle: Text('${partner['name'] ?? ''} · ${row['return_type_display'] ?? ''} · ${row['state_display'] ?? ''}'),
                                trailing: Text('${row['amount_total'] ?? 0}'),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => IsReturnDetailScreen(data: row)),
                                  );
                                  _load();
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class IsReturnCreateScreen extends StatefulWidget {
  const IsReturnCreateScreen({super.key, required this.category, required this.title});

  final String category;
  final String title;

  @override
  State<IsReturnCreateScreen> createState() => _IsReturnCreateScreenState();
}

class _IsReturnCreateScreenState extends State<IsReturnCreateScreen> {
  final ApiService _api = ApiService.instance;
  Map<String, dynamic>? _partner;
  String _returnType = 'return';
  final DateTime _date = DateTime.now();
  final List<Map<String, dynamic>> _lines = [];
  bool _saving = false;
  File? _challanImageFile;
  String? _challanImageBase64;
  String? _challanImageName;

  Future<void> _pickCustomer() async {
    final rows = await _api.getIsReturnCustomers();
    if (!mounted) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => ListView(
        children: [
          const ListTile(title: Text('Select IS Outlet')),
          for (final row in rows)
            ListTile(
              title: Text('${row['name'] ?? ''}'),
              subtitle: Text('${row['ss_code'] ?? ''}'),
              onTap: () => Navigator.pop(context, row),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _partner = picked);
  }

  Future<void> _addProduct() async {
    final line = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _IsProductSheet(),
    );
    if (line != null) setState(() => _lines.add(line));
  }

  Future<void> _pickChallanImage(ImageSource source) async {
    try {
      final XFile? picked = source == ImageSource.camera
          ? await AppCameraCaptureDialog.capture(context, title: 'Capture Return Challan')
          : await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 70);
      if (picked == null) return;
      final file = await MediaStorageService.persistPickedFile(picked, category: MediaCategory.damages);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _challanImageFile = file;
        _challanImageBase64 = base64Encode(bytes);
        _challanImageName = picked.name.isNotEmpty ? picked.name : 'return_challan.jpg';
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick photo: $error')));
      }
    }
  }

  Future<void> _save() async {
    if (_partner == null || _lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a customer and add at least one product.')));
      return;
    }
    if (_challanImageBase64 == null || _challanImageBase64!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload a photo of the return challan.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.createIsReturn({
        'partner_id': _partner!['id'],
        'return_category': widget.category,
        'return_type': _returnType,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'attachment_base64': _challanImageBase64,
        'attachment_filename': _challanImageName,
        'lines': _lines.map((line) => {
              'product_id': line['product_id'],
              if (line['lot_id'] != null) 'lot_id': line['lot_id'],
              'requested_qty': line['requested_qty'],
            }).toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New ${widget.title}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('1. Outlet & Request', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _pickCustomer,
            child: Text(_partner == null ? 'Select IS outlet...' : '${_partner!['name']}'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'return', label: Text('Return')),
              ButtonSegment(value: 'replacement', label: Text('Replacement')),
            ],
            selected: {_returnType},
            onSelectionChanged: (value) => setState(() => _returnType = value.first),
          ),
          const SizedBox(height: 16),
          const Text('Challan Photo Evidence *', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_challanImageFile == null)
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickChallanImage(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera'))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(onPressed: () => _pickChallanImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery'))),
              ],
            )
          else
            ListTile(
              leading: Image.file(_challanImageFile!, width: 48, height: 48, fit: BoxFit.cover),
              title: Text(_challanImageName ?? 'Photo attached'),
              trailing: IconButton(onPressed: () => setState(() {
                _challanImageFile = null;
                _challanImageBase64 = null;
                _challanImageName = null;
              }), icon: const Icon(Icons.delete_outline, color: Colors.red)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('2. Products', style: TextStyle(fontWeight: FontWeight.w700))),
              FilledButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('Add Product')),
            ],
          ),
          for (final line in _lines)
            ListTile(
              title: Text('${line['product_name'] ?? ''}'),
              subtitle: Text(line['lot_name'] == null ? 'Qty ${line['requested_qty']}' : 'Batch ${line['lot_name']} · Qty ${line['requested_qty']}'),
            ),
          const SizedBox(height: 8),
          const Text('Price comes from the original invoice. Batch is required for tracked products.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving' : 'Create Return Request')),
        ],
      ),
    );
  }
}

class IsReturnDetailScreen extends StatefulWidget {
  const IsReturnDetailScreen({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<IsReturnDetailScreen> createState() => _IsReturnDetailScreenState();
}

class _IsReturnDetailScreenState extends State<IsReturnDetailScreen> {
  late Map<String, dynamic> _data;
  bool _busy = false;
  final _collected = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    final lines = _data['lines'];
    if (lines is List) {
      for (final line in lines) {
        final map = Map<String, dynamic>.from(line as Map);
        _collected[map['id'] as int] = TextEditingController(text: '${map['collected_qty'] ?? ''}');
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _collected.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _actionKey(String? action) {
    switch (action) {
      case 'submit_dm':
        return AppAction.institutionReturnSubmitDm;
      case 'submit_coordinator':
        return AppAction.institutionReturnSubmitCoordinator;
      case 'submit_sales_operation':
        return AppAction.institutionReturnSubmitSalesOperation;
      case 'complete':
      case 'validate_challan':
        return AppAction.institutionReturnComplete;
      default:
        return null;
    }
  }

  Future<void> _act(String action, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: const Text('Confirm this step and send the request to the next approver?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      List<Map<String, dynamic>>? lines;
      final actions = _data['allowed_actions'];
      if (actions is Map && actions['can_edit_collected_qty'] == true) {
        lines = _collected.entries.map((entry) => {
              'id': entry.key,
              'collected_qty': double.tryParse(entry.value.text.trim()) ?? 0,
            }).toList();
      }
      final updated = await ApiService.instance.isReturnAction(_data['id'] as int, action, lines: lines);
      if (mounted) setState(() => _data = updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showVerification(Map<String, dynamic> line) {
    final users = line['user_lines'] is List ? line['user_lines'] as List : const [];
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Verification - ${line['product_name'] ?? ''}'),
        content: SizedBox(
          width: 420,
          child: users.isEmpty
              ? const Text('No user has recorded a quantity on this line yet.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final raw in users)
                        Builder(builder: (context) {
                          final row = Map<String, dynamic>.from(raw as Map);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${row['user_name'] ?? 'User'} · ${row['group_name'] ?? row['stage_display'] ?? ''}'),
                            subtitle: Text('Requested ${row['requested_qty']} · Collected ${row['collected_qty']}'),
                          );
                        }),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = _data['allowed_actions'] is Map ? Map<String, dynamic>.from(_data['allowed_actions'] as Map) : <String, dynamic>{};
    final lines = _data['lines'] is List ? _data['lines'] as List : const [];
    final next = actions['next_action']?.toString();
    final nextLabel = '${actions['next_action_label'] ?? next ?? ''}';
    final actionKey = _actionKey(next);
    final canAdvance = next != null && next.isNotEmpty && (actionKey == null || context.watch<AuthProvider>().canDo(actionKey));
    final partner = _data['partner'] is Map ? Map<String, dynamic>.from(_data['partner'] as Map) : <String, dynamic>{};
    final attachments = _data['attachments'] is List ? _data['attachments'] as List : const [];
    const stages = ['executive', 'dm', 'coordinator', 'sales_operation', 'completed'];
    const stageLabels = {
      'executive': 'Executive',
      'dm': 'DM',
      'coordinator': 'Coordinator',
      'sales_operation': 'Sales Ops',
      'completed': 'Completed',
    };
    final currentIndex = stages.indexOf(_data['state']?.toString() ?? '');
    return Scaffold(
      appBar: AppBar(title: Text('${_data['name'] ?? 'Return'}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < stages.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(stageLabels[stages[index]] ?? stages[index]),
                      backgroundColor: index <= currentIndex ? const Color(0xFFCCFBF1) : Colors.grey.shade100,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('${partner['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text('${_data['return_category_display'] ?? ''} · ${_data['return_type_display'] ?? ''} · ${_data['state_display'] ?? ''}'),
          Text('Invoice value ${_data['amount_total'] ?? 0}'),
          if (attachments.isNotEmpty) Text('Challan photo: ${(attachments.first as Map)['name'] ?? 'attached'}'),
          if (_data['replacement_delivery'] != null) Text('Replacement delivery: ${(_data['replacement_delivery'] as Map)['name'] ?? ''}'),
          const SizedBox(height: 12),
          for (final raw in lines)
            Builder(builder: (context) {
              final line = Map<String, dynamic>.from(raw as Map);
              final id = line['id'] as int;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${line['product_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Batch ${line['lot_name'] ?? '-'}'),
                      Text('Requested ${line['requested_qty']} · Invoice price ${line['invoice_price']}'),
                      if (actions['can_edit_collected_qty'] == true)
                        TextField(
                          controller: _collected[id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Collected / replacement quantity'),
                        )
                      else
                        Text('Collected ${line['collected_qty']}'),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _showVerification(line),
                          child: const Text('User verification'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (canAdvance)
            FilledButton(onPressed: _busy ? null : () => _act(next, nextLabel), child: Text(nextLabel))
          else if (next != null && next.isNotEmpty)
            Text('This step is waiting for the next approver.', style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class _IsProductSheet extends StatefulWidget {
  const _IsProductSheet();

  @override
  State<_IsProductSheet> createState() => _IsProductSheetState();
}

class _IsProductSheetState extends State<_IsProductSheet> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _qty = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _lots = [];
  Map<String, dynamic>? _product;
  Map<String, dynamic>? _lot;
  int? _categoryId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ApiService.instance;
    final categories = await api.getIsReturnCategories();
    final products = await api.getIsReturnProducts(search: _search.text.trim(), appCategoryId: _categoryId);
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _products = products;
      _loading = false;
    });
  }

  Future<void> _select(Map<String, dynamic> product) async {
    List<Map<String, dynamic>> lots = [];
    if (product['tracking'] == 'lot' || product['tracking'] == 'serial') {
      lots = await ApiService.instance.getIsReturnLots(product['id'] as int);
    }
    if (!mounted) return;
    setState(() {
      _product = product;
      _lots = lots;
      _lot = null;
    });
  }

  bool get _tracked => _product?['tracking'] == 'lot' || _product?['tracking'] == 'serial';

  void _add() {
    final qty = double.tryParse(_qty.text.trim()) ?? 0;
    if (_product == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the requested quantity.')));
      return;
    }
    if (_tracked && _lot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a batch for this product.')));
      return;
    }
    Navigator.pop(context, {
      'product_id': _product!['id'],
      'product_name': _product!['name'],
      'lot_id': _lot?['id'],
      'lot_name': _lot?['name'],
      'requested_qty': qty,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: 560,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(hintText: 'Search product'),
                  onSubmitted: (_) => _load(),
                ),
              ),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(label: const Text('All Categories'), selected: _categoryId == null, onSelected: (_) {
                      setState(() => _categoryId = null);
                      _load();
                    }),
                    for (final category in _categories)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text('${category['name']}'),
                          selected: _categoryId == category['id'],
                          onSelected: (_) {
                            setState(() => _categoryId = category['id'] as int);
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _product == null
                        ? ListView(
                            children: [
                              for (final product in _products)
                                ListTile(
                                  title: Text('${product['name'] ?? ''}'),
                                  subtitle: Text('${product['default_code'] ?? ''} · ${(product['uom'] is Map) ? (product['uom'] as Map)['name'] : ''}'),
                                  onTap: () => _select(product),
                                ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              Text('${_product!['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              TextField(controller: _qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Requested quantity')),
                              if (_tracked)
                                ..._lots.map((lot) => ListTile(
                                      leading: Icon(_lot?['id'] == lot['id'] ? Icons.radio_button_checked : Icons.radio_button_off),
                                      title: Text('${lot['name']}'),
                                      onTap: () => setState(() => _lot = lot),
                                    )),
                            ],
                          ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(onPressed: _product == null ? null : _add, child: const Text('Add Product')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
