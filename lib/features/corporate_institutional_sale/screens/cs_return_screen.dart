import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/app_camera_capture_dialog.dart';
import 'package:secondary_sales/data/api/api_service.dart';

class CsReturnScreen extends StatefulWidget {
  const CsReturnScreen({
    super.key,
    required this.category,
    required this.title,
    required this.createLabel,
  });

  final String category;
  final String title;
  final String createLabel;

  @override
  State<CsReturnScreen> createState() => _CsReturnScreenState();
}

class _CsReturnScreenState extends State<CsReturnScreen> {
  final ApiService _api = ApiService.instance;
  final TextEditingController _search = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _returns = [];
  List<Map<String, dynamic>> _customers = [];
  String _state = 'all';
  String _order = 'date desc';
  int? _partnerId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _loading = true;
  String? _error;

  static const _stages = <(String, String)>[
    ('all', 'All'),
    ('admin', 'Admin Officer'),
    ('dm', 'Delivery Man'),
    ('coordinator', 'Coordinator'),
    ('sales_operation', 'Sales Operations'),
    ('completed', 'Completed'),
  ];

  static const _sorts = <(String, String, IconData)>[
    ('date desc', 'Date: Newest first', Icons.schedule),
    ('date asc', 'Date: Oldest first', Icons.history),
    ('partner asc', 'Customer: A to Z', Icons.sort_by_alpha),
    ('partner desc', 'Customer: Z to A', Icons.sort_by_alpha),
    ('name asc', 'Reference: A to Z', Icons.tag),
    ('name desc', 'Reference: Z to A', Icons.tag),
    ('state', 'Status / Stage', Icons.flag_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  String _iso(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getCsReturns(
        category: widget.category,
        state: _state,
        search: _search.text.trim(),
        partnerId: _partnerId,
        dateFrom: _dateFrom == null ? null : _iso(_dateFrom!),
        dateTo: _dateTo == null ? null : _iso(_dateTo!),
        order: _order,
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

  Future<void> _loadCustomers() async {
    try {
      final rows = await _api.getCsReturnCustomers();
      if (mounted) setState(() => _customers = rows);
    } catch (_) {}
  }

  void _onSearch(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: _dateFrom ?? now, end: _dateTo ?? now),
    );
    if (picked == null) return;
    setState(() {
      _dateFrom = picked.start;
      _dateTo = picked.end;
    });
    _load();
  }

  String _dateLabel() {
    if (_dateFrom == null || _dateTo == null) return 'All Dates';
    final same = _dateFrom!.year == _dateTo!.year && _dateFrom!.month == _dateTo!.month && _dateFrom!.day == _dateTo!.day;
    if (same) return DateFormat('dd MMM yyyy').format(_dateFrom!);
    return '${DateFormat('dd MMM').format(_dateFrom!)} - ${DateFormat('dd MMM').format(_dateTo!)}';
  }

  String _customerLabel() {
    if (_partnerId == null) return 'All Customers';
    for (final row in _customers) {
      if (row['id'] == _partnerId) {
        final name = row['name']?.toString() ?? 'Customer';
        return name.length > 16 ? '${name.substring(0, 14)}...' : name;
      }
    }
    return 'Customer';
  }

  Future<void> _pickCustomerFilter() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              const ListTile(title: Text('Customers')),
              ListTile(
                title: const Text('All Customers'),
                onTap: () => Navigator.pop(context, 0),
              ),
              ..._customers.map((row) => ListTile(
                    title: Text('${row['name'] ?? ''}'),
                    subtitle: row['ss_code'] == null ? null : Text('${row['ss_code']}'),
                    onTap: () => Navigator.pop(context, row['id'] as int),
                  )),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() => _partnerId = picked == 0 ? null : picked);
    _load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CsReturnCreateScreen(
          category: widget.category,
          title: widget.title,
        ),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _openDetail(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _CsReturnDetailScreen(returnId: id)),
    );
    _load();
  }

  Color _stageColor(String state) {
    switch (state) {
      case 'completed':
        return const Color(0xFF16A34A);
      case 'sales_operation':
        return const Color(0xFF7C3AED);
      case 'coordinator':
        return const Color(0xFFD97706);
      case 'dm':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _filterChip({
    required bool active,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final color = active ? AppColors.primaryStrong : Colors.grey.shade700;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primarySoft : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? AppColors.primaryStrong : Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.primaryStrong : AppColors.textPrimary),
                ),
              ),
              if (active && onClear != null)
                InkWell(
                  onTap: onClear,
                  child: Icon(Icons.close, size: 14, color: AppColors.primaryStrong),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final partner = row['partner'] is Map ? Map<String, dynamic>.from(row['partner'] as Map) : <String, dynamic>{};
    final lines = row['lines'] is List ? row['lines'] as List : const [];
    final state = row['state']?.toString() ?? '';
    final date = row['date']?.toString();
    return InkWell(
      onTap: () => _openDetail(row['id'] as int),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${row['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _stageColor(state).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${row['state_display'] ?? ''}'.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _stageColor(state)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${partner['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (partner['ss_code'] != null)
              Text('SS Code: ${partner['ss_code']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(date ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(width: 12),
                Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${lines.length} Products', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const Spacer(),
                Text('Total: ${row['amount_total'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateActive = _dateFrom != null;
    final customerActive = _partnerId != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: Text(widget.createLabel),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search by reference or customer name',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _filterChip(
                      active: dateActive,
                      icon: Icons.calendar_month_outlined,
                      label: _dateLabel(),
                      onTap: _pickDates,
                      onClear: () {
                        setState(() {
                          _dateFrom = null;
                          _dateTo = null;
                        });
                        _load();
                      },
                    ),
                    const SizedBox(width: 6),
                    _filterChip(
                      active: customerActive,
                      icon: Icons.storefront_outlined,
                      label: _customerLabel(),
                      onTap: _pickCustomerFilter,
                      onClear: () {
                        setState(() => _partnerId = null);
                        _load();
                      },
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      initialValue: _order,
                      onSelected: (value) {
                        setState(() => _order = value);
                        _load();
                      },
                      itemBuilder: (context) => _sorts.map((item) {
                        return PopupMenuItem<String>(
                          value: item.$1,
                          child: Row(
                            children: [
                              Icon(item.$3, size: 18, color: _order == item.$1 ? AppColors.primaryStrong : Colors.grey.shade700),
                              const SizedBox(width: 10),
                              Text(item.$2),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.swap_vert, size: 18, color: AppColors.primaryStrong),
                            SizedBox(width: 2),
                            Text('Sort', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryStrong)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _stages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final stage = _stages[index];
                      final selected = _state == stage.$1;
                      return ChoiceChip(
                        label: Text(stage.$2),
                        selected: selected,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? Colors.white : AppColors.textPrimary,
                        ),
                        selectedColor: AppColors.primaryStrong,
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (_) {
                          setState(() => _state = stage.$1);
                          _load();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _returns.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.assignment_return_outlined, size: 56, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text('No ${widget.title.toLowerCase()} found', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                              itemCount: _returns.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) => _card(_returns[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class CsReturnCreateScreen extends StatefulWidget {
  const CsReturnCreateScreen({super.key, required this.category, required this.title});

  final String category;
  final String title;

  @override
  State<CsReturnCreateScreen> createState() => _CsReturnCreateScreenState();
}

class _CsReturnCreateScreenState extends State<CsReturnCreateScreen> {
  final ApiService _api = ApiService.instance;
  Map<String, dynamic>? _partner;
  DateTime _date = DateTime.now();
  final List<Map<String, dynamic>> _lines = [];
  bool _saving = false;
  File? _challanImageFile;
  String? _challanImageBase64;
  String? _challanImageName;

  static const _labels = <String, String>{
    'non_saleable': 'Non-Saleable',
    'short_dated': 'Short-Dated / Expired Product',
    'quality': 'Quality Issue',
    'saleable': 'Saleable Return',
  };

  Future<Map<String, dynamic>?> _pick(String title, Future<List<Map<String, dynamic>>> Function() loader) async {
    final rows = await loader();
    if (!mounted) return null;
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (rows.isEmpty) const ListTile(title: Text('Nothing to select')),
              ...rows.map((row) => ListTile(
                    title: Text('${row['name'] ?? ''}'),
                    subtitle: row['ss_code'] == null ? null : Text('${row['ss_code']}'),
                    onTap: () => Navigator.pop(context, row),
                  )),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addProduct() async {
    final line = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CsReturnProductSheet(),
    );
    if (line == null) return;
    setState(() => _lines.add(line));
  }

  Future<void> _pickChallanImage(ImageSource source) async {
    try {
      final XFile? picked;
      if (source == ImageSource.camera) {
        picked = await AppCameraCaptureDialog.capture(
          context,
          title: 'Capture Return Challan',
          helperTip: 'Align the return challan document inside the frame',
        );
      } else {
        picked = await ImagePicker().pickImage(
          source: source,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 70,
        );
      }
      if (picked == null) return;
      final file = await MediaStorageService.persistPickedFile(picked, category: MediaCategory.damages);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _challanImageFile = file;
        _challanImageBase64 = base64Encode(bytes);
        _challanImageName = picked!.name.isNotEmpty ? picked.name : 'return_challan.jpg';
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $error')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_partner == null || _lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a customer and add at least one product.')),
      );
      return;
    }
    if (_challanImageBase64 == null || _challanImageBase64!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload a photo of the return challan.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.createCsReturn({
        'partner_id': _partner!['id'],
        'return_category': widget.category,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double get _totalQty => _lines.fold<double>(0, (sum, line) => sum + ((line['requested_qty'] as num?)?.toDouble() ?? 0));

  Widget _challanPhoto() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _challanImageFile == null ? Colors.grey.shade200 : AppColors.primaryStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Challan Photo Evidence *', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Upload a clear photo of the return challan.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          if (_challanImageFile == null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickChallanImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickChallanImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(_challanImageFile!, width: 50, height: 50, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_challanImageName ?? 'Photo attached', maxLines: 1, overflow: TextOverflow.ellipsis)),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => setState(() {
                    _challanImageFile = null;
                    _challanImageBase64 = null;
                    _challanImageName = null;
                  }),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text('New ${_labels[widget.category] ?? 'Return'}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('1. Outlet & Return Details', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select CS Outlet'),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await _pick('Customers', () => _api.getCsReturnCustomers());
                    if (picked != null) setState(() => _partner = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_partner?['name']?.toString() ?? 'Select allowed outlet...')),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Return Date'),
                          child: Text(DateFormat('yyyy-MM-dd').format(_date)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Category'),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _labels[widget.category] ?? widget.category,
                              style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _challanPhoto(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('2. Returned Product Items (${_lines.length})', style: const TextStyle(fontWeight: FontWeight.w700))),
              FilledButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('Add Product')),
            ],
          ),
          if (_lines.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text('No products added yet'),
                  Text('Tap Add Product to add returned items and batches', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            )
          else
            ..._lines.asMap().entries.map((entry) {
              final line = entry.value;
              return Card(
                child: ListTile(
                  title: Text('${line['product_name'] ?? ''}'),
                  subtitle: Text(
                    line['lot_name'] == null
                        ? 'Qty ${line['requested_qty']}'
                        : 'Batch ${line['lot_name']} · Qty ${line['requested_qty']}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _lines.removeAt(entry.key)),
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('Total Return Quantity')),
                Text('$_totalQty', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryStrong)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Price comes from the original invoice. Replacement is not available. Batch is required for tracked products.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving' : 'Create Return Request'),
          ),
        ],
      ),
    );
  }
}

class _CsReturnDetailScreen extends StatefulWidget {
  const _CsReturnDetailScreen({required this.returnId});

  final int returnId;

  @override
  State<_CsReturnDetailScreen> createState() => _CsReturnDetailScreenState();
}

class _CsReturnDetailScreenState extends State<_CsReturnDetailScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;
  final _collected = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _collected.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.instance.getCsReturns();
      final rows = data['returns'];
      Map<String, dynamic>? match;
      if (rows is List) {
        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          if (map['id'] == widget.returnId) match = map;
        }
      }
      if (!mounted) return;
      if (match == null) {
        setState(() => _error = 'Return was not found.');
        return;
      }
      final lines = match['lines'];
      if (lines is List) {
        for (final line in lines) {
          final map = Map<String, dynamic>.from(line as Map);
          final id = map['id'] as int;
          _collected.putIfAbsent(id, () => TextEditingController(text: '${map['collected_qty'] ?? ''}'));
        }
      }
      setState(() => _data = match);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  String? _actionKey(String? action) {
    switch (action) {
      case 'submit_dm':
        return AppAction.corporateReturnSubmitDm;
      case 'submit_coordinator':
        return AppAction.corporateReturnSubmitCoordinator;
      case 'submit_sales_operation':
        return AppAction.corporateReturnSubmitSalesOperation;
      case 'complete':
      case 'validate_challan':
        return AppAction.corporateReturnComplete;
      default:
        return null;
    }
  }

  Future<void> _act(String action, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Text('Confirm this step and send the return to the next approver?'),
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
      final actions = _data?['allowed_actions'];
      final canCollect = actions is Map && actions['can_edit_collected_qty'] == true;
      if (canCollect) {
        lines = _collected.entries.map((entry) => {
              'id': entry.key,
              'collected_qty': double.tryParse(entry.value.text.trim()) ?? 0,
            }).toList();
      }
      final updated = await ApiService.instance.csReturnAction(widget.returnId, action, lines: lines);
      if (mounted) setState(() => _data = updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
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
    final data = _data;
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: const Text('Return')), body: Center(child: Text(_error!)));
    }
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final actions = data['allowed_actions'] is Map ? Map<String, dynamic>.from(data['allowed_actions'] as Map) : <String, dynamic>{};
    final lines = data['lines'] is List ? data['lines'] as List : const [];
    final next = actions['next_action']?.toString();
    final nextLabel = '${actions['next_action_label'] ?? next ?? ''}';
    final actionKey = _actionKey(next);
    final canAdvance = next != null && next.isNotEmpty && (actionKey == null || context.watch<AuthProvider>().canDo(actionKey));
    final partner = data['partner'] is Map ? Map<String, dynamic>.from(data['partner'] as Map) : <String, dynamic>{};
    final attachments = data['attachments'] is List ? data['attachments'] as List : const [];
    const stages = ['admin', 'dm', 'coordinator', 'sales_operation', 'completed'];
    const stageLabels = {
      'admin': 'Admin',
      'dm': 'DM',
      'coordinator': 'Coordinator',
      'sales_operation': 'Sales Ops',
      'completed': 'Completed',
    };
    final current = data['state']?.toString();
    final currentIndex = stages.indexOf(current ?? '');
    return Scaffold(
      appBar: AppBar(title: Text('${data['name'] ?? 'Return'}')),
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
                      backgroundColor: index <= currentIndex ? AppColors.primaryStrong.withValues(alpha: 0.15) : Colors.grey.shade100,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('${partner['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text('${data['return_category_display'] ?? ''} · ${data['state_display'] ?? ''}'),
          const SizedBox(height: 8),
          Text('Invoice value ${data['amount_total'] ?? 0}'),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Challan photo: ${(attachments.first as Map)['name'] ?? 'attached'}'),
          ],
          const SizedBox(height: 12),
          ...lines.map((raw) {
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
                        decoration: const InputDecoration(labelText: 'Collected quantity'),
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
            FilledButton(
              onPressed: _busy ? null : () => _act(next, nextLabel),
              child: Text(nextLabel),
            )
          else if (next != null && next.isNotEmpty)
            Text(
              'This step is waiting for the next approver.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
        ],
      ),
    );
  }
}

class _CsReturnProductSheet extends StatefulWidget {
  const _CsReturnProductSheet();

  @override
  State<_CsReturnProductSheet> createState() => _CsReturnProductSheetState();
}

class _CsReturnProductSheetState extends State<_CsReturnProductSheet> {
  final ApiService _api = ApiService.instance;
  final TextEditingController _search = TextEditingController();
  final TextEditingController _qty = TextEditingController();
  final TextEditingController _lotSearch = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _lots = [];
  Map<String, dynamic>? _product;
  Map<String, dynamic>? _lot;
  int? _categoryId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _qty.dispose();
    _lotSearch.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await _api.getCsReturnCategories();
      if (mounted) setState(() => _categories = rows);
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.getCsReturnProducts(
        search: _search.text.trim(),
        appCategoryId: _categoryId,
      );
      if (!mounted) return;
      setState(() {
        _products = rows;
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

  void _onSearch(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _loadProducts);
  }

  Future<void> _selectProduct(Map<String, dynamic> product) async {
    List<Map<String, dynamic>> lots = [];
    if (product['tracking'] == 'lot' || product['tracking'] == 'serial') {
      lots = await _api.getCsReturnLots(product['id'] as int);
    }
    if (!mounted) return;
    setState(() {
      _product = product;
      _lots = lots;
      _lot = null;
      _qty.text = '';
    });
  }

  bool get _tracked => _product?['tracking'] == 'lot' || _product?['tracking'] == 'serial';

  Future<void> _loadLots() async {
    final product = _product;
    if (product == null || !_tracked) return;
    final lots = await _api.getCsReturnLots(product['id'] as int, search: _lotSearch.text.trim());
    if (!mounted) return;
    setState(() => _lots = lots);
  }

  void _confirm() {
    final qty = double.tryParse(_qty.text.trim()) ?? 0;
    if (_product == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the requested quantity.')),
      );
      return;
    }
    if (_tracked && _lot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a batch for this product.')),
      );
      return;
    }
    Navigator.pop(context, {
      'product_id': _product!['id'],
      'product_name': _product!['name'],
      if (_lot != null) 'lot_id': _lot!['id'],
      'lot_name': _lot?['name'],
      'requested_qty': qty,
    });
  }

  String _uom(Map<String, dynamic> product) {
    final uom = product['uom'];
    if (uom is Map && uom['name'] != null) return '${uom['name']}';
    return 'Unit';
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('All Categories'),
              selected: _categoryId == null,
              selectedColor: AppColors.primaryStrong,
              labelStyle: TextStyle(color: _categoryId == null ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              onSelected: (_) {
                setState(() => _categoryId = null);
                _loadProducts();
              },
            ),
          ),
          ..._categories.map((category) {
            final id = category['id'] as int;
            final selected = _categoryId == id;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('${category['name'] ?? ''}'),
                selected: selected,
                selectedColor: AppColors.primaryStrong,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                onSelected: (_) {
                  setState(() => _categoryId = id);
                  _loadProducts();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.85;
    return SizedBox(
      height: height,
      child: _product == null ? _picker() : _quantity(),
    );
  }

  Widget _picker() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(child: Text('Select Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Search products by name or code...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _categoryChips(),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _products.isEmpty
                      ? const Center(child: Text('No Corporate Sales products found'))
                      : ListView.separated(
                          itemCount: _products.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            final code = product['default_code']?.toString() ?? '';
                            return ListTile(
                              title: Text('${product['name'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              subtitle: Text(code.isEmpty ? 'UoM: ${_uom(product)}' : 'Code: $code • UoM: ${_uom(product)}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _selectProduct(product),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _quantity() {
    final product = _product!;
    final code = product['default_code']?.toString() ?? '';
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Requested quantity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              Text('${product['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(code.isEmpty ? 'UoM: ${_uom(product)}' : 'Code: $code • UoM: ${_uom(product)}'),
              TextButton(onPressed: () => setState(() => _product = null), child: const Text('Change')),
              TextField(
                controller: _qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Requested quantity'),
              ),
              if (_tracked) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _lotSearch,
                  onChanged: (_) => _loadLots(),
                  decoration: const InputDecoration(
                    labelText: 'Batch number',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                if (_lot != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Selected batch ${_lot!['name']}'),
                    trailing: const Icon(Icons.check, color: AppColors.primaryStrong),
                  ),
                ..._lots.map((lot) => ListTile(
                      title: Text('${lot['name'] ?? ''}'),
                      trailing: _lot?['id'] == lot['id'] ? const Icon(Icons.check, color: AppColors.primaryStrong) : null,
                      onTap: () => setState(() => _lot = lot),
                    )),
                if (_lots.isEmpty) const Text('No batch found for this product.'),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton(onPressed: _confirm, child: const Text('Add Product')),
        ),
      ],
    );
  }
}
