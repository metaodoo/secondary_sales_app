import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/modern_trade/mt_return_provider.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_product_selection_sheet.dart';

class MtReturnCreateScreen extends StatefulWidget {
  final String returnBucket; // 'saleable' or 'non_saleable'
  final String title;

  const MtReturnCreateScreen({
    super.key,
    required this.returnBucket,
    required this.title,
  });

  @override
  State<MtReturnCreateScreen> createState() => _MtReturnCreateScreenState();
}

class _MtReturnCreateScreenState extends State<MtReturnCreateScreen> {
  late String _selectedBucket;
  int? _selectedOutletId;
  DateTime _selectedDate = DateTime.now();
  final List<Map<String, dynamic>> _lines = [];

  @override
  void initState() {
    super.initState();
    _selectedBucket = widget.returnBucket;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MtReturnProvider>().fetchPrepareContext();
    });
  }

  void _onAddProduct() async {
    final result = await MtReturnProductSelectionSheet.show(
      context,
      returnBucket: _selectedBucket,
    );
    if (result != null) {
      setState(() {
        _lines.add(result);
      });
    }
  }

  void _onRemoveLine(int index) {
    setState(() {
      _lines.removeAt(index);
    });
  }

  double get _totalSaleableQty => _lines.fold(0.0, (sum, l) => sum + (l['saleable_qty'] as double? ?? 0.0));
  double get _totalNonSaleableQty => _lines.fold(0.0, (sum, l) => sum + (l['non_saleable_qty'] as double? ?? 0.0));
  double get _totalQualityQty => _lines.fold(0.0, (sum, l) => sum + (l['quality_qty'] as double? ?? 0.0));
  double get _totalQty => _selectedBucket == 'saleable'
      ? _totalSaleableQty + _totalNonSaleableQty
      : _totalNonSaleableQty + _totalQualityQty;

  Map<String, dynamic>? _getOutletById(List<Map<String, dynamic>> outlets, int? id) {
    if (id == null) return null;
    try {
      return outlets.firstWhere((o) => o['id'] == id);
    } catch (_) {
      return null;
    }
  }

  void _onSubmit() async {
    final provider = context.read<MtReturnProvider>();
    final outlets = (provider.prepareData?['outlets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final selectedOutlet = _getOutletById(outlets, _selectedOutletId);

    if (selectedOutlet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an outlet/customer')),
      );
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product line')),
      );
      return;
    }

    final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
    final linesPayload = _lines.map((l) {
      return {
        'product_id': l['product_id'],
        'lot_id': l['lot_id'],
        'saleable_qty': l['saleable_qty'],
        'non_saleable_qty': l['non_saleable_qty'],
        'quality_qty': l['quality_qty'],
      };
    }).toList();

    final result = await provider.createReturn(
      partnerId: selectedOutlet['id'] as int,
      returnBucket: _selectedBucket,
      date: dateStr,
      lines: linesPayload,
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Return request ${result.name} created successfully!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop();
    } else if (provider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MtReturnProvider>();
    final isSaleable = _selectedBucket == 'saleable';
    final outlets = (provider.prepareData?['outlets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final selectedOutlet = _getOutletById(outlets, _selectedOutletId);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outlet Card
            _buildSectionHeader('1. Outlet & Return Details'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select MT Outlet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int?>(
                    value: _selectedOutletId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Select outlet...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: outlets.map((o) {
                      final id = o['id'] as int?;
                      final name = o['name']?.toString() ?? '';
                      final ssCode = o['ss_code']?.toString() ?? '';
                      return DropdownMenuItem<int?>(
                        value: id,
                        child: Text(
                          ssCode.isNotEmpty ? '$name [$ssCode]' : name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedOutletId = val),
                  ),
                  if (selectedOutlet != null) ...[
                    const SizedBox(height: 12),
                    _buildOutletMetadata(selectedOutlet),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Return Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) setState(() => _selectedDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: isSaleable ? Colors.teal.shade50 : Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSaleable ? Colors.teal.shade300 : Colors.purple.shade300,
                                ),
                              ),
                              child: Text(
                                isSaleable ? 'Saleable Return' : 'Non-Saleable Return',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSaleable ? Colors.teal.shade800 : Colors.purple.shade800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Product Lines Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('2. Returned Product Items (${_lines.length})'),
                ElevatedButton.icon(
                  onPressed: _onAddProduct,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryStrong,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Lines List
            if (_lines.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_shopping_cart, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No products added yet',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "+ Add Product" to add returned items and lots',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _lines.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final line = _lines[index];
                  final product = line['product'] as Map<String, dynamic>? ?? {};
                  final lot = line['lot'] as Map<String, dynamic>?;
                  final prodName = product['name']?.toString() ?? 'Product';
                  final prodCode = product['default_code']?.toString() ?? '';
                  final uom = product['uom'] is Map ? product['uom']['name']?.toString() ?? 'Unit' : 'Unit';

                  final saleableQty = line['saleable_qty'] as double? ?? 0.0;
                  final nonSaleableQty = line['non_saleable_qty'] as double? ?? 0.0;
                  final qualityQty = line['quality_qty'] as double? ?? 0.0;
                  final totalLineQty = isSaleable ? saleableQty + nonSaleableQty : nonSaleableQty + qualityQty;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prodName,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    prodCode.isNotEmpty ? 'Code: $prodCode • UoM: $uom' : 'UoM: $uom',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  if (lot != null) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        'Lot: ${lot['name']}',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _onRemoveLine(index),
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (isSaleable) ...[
                              _buildLineQtyBadge('Saleable', saleableQty, Colors.teal),
                              _buildLineQtyBadge('Non-Saleable', nonSaleableQty, Colors.orange),
                            ] else ...[
                              _buildLineQtyBadge('Non-Saleable', nonSaleableQty, Colors.orange),
                              _buildLineQtyBadge('Quality', qualityQty, Colors.purple),
                            ],
                            _buildLineQtyBadge('Total Qty', totalLineQty, AppColors.primaryStrong, isBold: true),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),

            // Summary Totals & Auto Submit
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Return Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(
                        _totalQty.toStringAsFixed(_totalQty.truncateToDouble() == _totalQty ? 0 : 2),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryStrong),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: provider.isActionLoading ? null : _onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryStrong,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: provider.isActionLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create Return Request',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    );
  }

  Widget _buildOutletMetadata(Map<String, dynamic> outlet) {
    final zone = outlet['zone'] as Map?;
    final wh = outlet['warehouse'] as Map?;
    final scrapLoc = outlet['return_scrap_location'] as Map?;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (zone != null)
            Text('Zone: ${zone['name']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          if (wh != null)
            Text('Warehouse: ${wh['name']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          if (scrapLoc != null)
            Text('Scrap Loc: ${scrapLoc['name']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildLineQtyBadge(String label, double qty, Color color, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        '$label: ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
