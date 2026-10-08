import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/widgets/app_camera_capture_dialog.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/modern_trade/mt_return_provider.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_product_selection_sheet.dart';

class MtReturnCreateScreen extends StatefulWidget {
  final String returnBucket; // 'saleable', 'non_saleable', 'quality'
  final String returnType; // 'return' or 'replacement'
  final String title;

  const MtReturnCreateScreen({
    super.key,
    required this.returnBucket,
    this.returnType = 'replacement',
    required this.title,
  });

  @override
  State<MtReturnCreateScreen> createState() => _MtReturnCreateScreenState();
}

class _MtReturnCreateScreenState extends State<MtReturnCreateScreen> {
  late String _selectedBucket;
  late String _selectedReturnType;
  int? _selectedOutletId;
  DateTime _selectedDate = DateTime.now();
  final List<Map<String, dynamic>> _lines = [];

  File? _challanImageFile;
  String? _challanImageBase64;
  String? _challanImageName;

  @override
  void initState() {
    super.initState();
    _selectedBucket = widget.returnBucket;
    _selectedReturnType = widget.returnBucket == 'saleable' ? 'return' : widget.returnType;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MtReturnProvider>().fetchPrepareContext();
    });
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
        final picker = ImagePicker();
        picked = await picker.pickImage(
          source: source,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 70,
        );
      }
      if (picked == null) return;
      final photo = picked;
      final file = await MediaStorageService.persistPickedFile(photo, category: MediaCategory.damages);
      if (file == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image file is invalid or empty. Please retake.')),
          );
        }
        return;
      }
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      setState(() {
        _challanImageFile = file;
        _challanImageBase64 = base64Str;
        _challanImageName = photo.name.isNotEmpty
            ? photo.name
            : 'return_challan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  void _onAddProduct() async {
    final result = await MtReturnProductSelectionSheet.show(
      context,
      returnBucket: _selectedBucket,
      state: 'kao',
    );
    if (result != null) {
      setState(() {
        _lines.add(result);
      });
    }
  }

  void _onEditLine(int index) async {
    final currentLine = _lines[index];
    final result = await MtReturnProductSelectionSheet.show(
      context,
      returnBucket: _selectedBucket,
      initialLine: currentLine,
      state: 'kao',
    );
    if (result != null) {
      setState(() {
        _lines[index] = result;
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
  double get _totalAmount => _lines.fold(0.0, (sum, l) {
    final prod = l['product'] as Map?;
    final price = prod != null ? (prod['list_price'] as num?)?.toDouble() ?? 0.0 : 0.0;
    final qty = _selectedBucket == 'saleable'
        ? ((l['saleable_qty'] as num?)?.toDouble() ?? 0.0) + ((l['non_saleable_qty'] as num?)?.toDouble() ?? 0.0)
        : ((l['non_saleable_qty'] as num?)?.toDouble() ?? 0.0) + ((l['quality_qty'] as num?)?.toDouble() ?? 0.0);
    return sum + (price * qty);
  });

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

    for (final l in _lines) {
      final product = l['product'] as Map<String, dynamic>?;
      final tracking = product?['tracking']?.toString();
      final isTracked = tracking == 'lot' || tracking == 'serial';
      if (isTracked && (l['lot_id'] == null || l['lot_id'] == 0)) {
        final prodName = product?['name']?.toString() ?? 'Tracked product';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Lot selection is mandatory for tracked product "$prodName".'),
          ),
        );
        return;
      }
    }

    if (_challanImageBase64 == null || _challanImageBase64!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Return Challan Photo Evidence is mandatory for Modern Trade Return.'),
          backgroundColor: Colors.red,
        ),
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
      returnType: _selectedReturnType,
      date: dateStr,
      lines: linesPayload,
      attachmentBase64: _challanImageBase64,
      attachmentFilename: _challanImageName,
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
    final isQuality = _selectedBucket == 'quality';
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
                                color: isSaleable
                                    ? Colors.teal.shade50
                                    : (isQuality ? Colors.purple.shade50 : Colors.red.shade50),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSaleable
                                      ? Colors.teal.shade300
                                      : (isQuality ? Colors.purple.shade300 : Colors.red.shade300),
                                ),
                              ),
                              child: Text(
                                isSaleable
                                    ? 'Saleable Return'
                                    : (isQuality ? 'Quality Return' : 'Non-Saleable Return'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSaleable
                                      ? Colors.teal.shade800
                                      : (isQuality ? Colors.purple.shade800 : Colors.red.shade800),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isSaleable) ...[
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Return Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedReturnType = 'return'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedReturnType == 'return' ? const Color(0xFFFFF3E0) : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _selectedReturnType == 'return' ? const Color(0xFFE65100) : Colors.grey.shade300,
                                      width: _selectedReturnType == 'return' ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.assignment_return_outlined,
                                        size: 16,
                                        color: _selectedReturnType == 'return' ? const Color(0xFFE65100) : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Return (Scrap)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _selectedReturnType == 'return' ? const Color(0xFFE65100) : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _selectedReturnType = 'replacement'),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedReturnType == 'replacement' ? const Color(0xFFE1F5FE) : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _selectedReturnType == 'replacement' ? const Color(0xFF0288D1) : Colors.grey.shade300,
                                      width: _selectedReturnType == 'replacement' ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.published_with_changes_outlined,
                                        size: 16,
                                        color: _selectedReturnType == 'replacement' ? const Color(0xFF0288D1) : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Replacement',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _selectedReturnType == 'replacement' ? const Color(0xFF0288D1) : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedReturnType == 'return'
                              ? '• Items sent to scrap only. No replacement delivery will be generated.'
                              : '• Items sent to scrap AND replacement goods will be delivered to outlet.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Photo Evidence Card
            _buildPhotoEvidenceSection(),

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
                  final price = (product['list_price'] as num?)?.toDouble() ?? 0.0;
                  final subtotal = price * totalLineQty;

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _onEditLine(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
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
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _onEditLine(index),
                                      icon: const Icon(Icons.edit_outlined, color: AppColors.primaryStrong, size: 20),
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Edit quantity & lot',
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _onRemoveLine(index),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Remove',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (price > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Price: ৳${price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryStrong,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Subtotal: ৳${subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (isSaleable) ...[
                                  _buildLineQtyBadge('Saleable', saleableQty, Colors.teal),
                                  if (nonSaleableQty > 0)
                                    _buildLineQtyBadge('Non-Saleable', nonSaleableQty, Colors.orange),
                                ] else if (_selectedBucket == 'quality') ...[
                                  _buildLineQtyBadge('Quality', qualityQty, Colors.purple),
                                  if (nonSaleableQty > 0)
                                    _buildLineQtyBadge('Non-Saleable', nonSaleableQty, Colors.orange),
                                ] else ...[
                                  _buildLineQtyBadge('Non-Saleable', nonSaleableQty, Colors.orange),
                                  if (qualityQty > 0)
                                    _buildLineQtyBadge('Quality', qualityQty, Colors.purple),
                                ],
                                _buildLineQtyBadge('Total Qty', totalLineQty, AppColors.primaryStrong, isBold: true),
                              ],
                            ),
                          ],
                        ),
                      ),
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
                  if (_totalAmount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Return Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(
                          '৳${_totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryStrong),
                        ),
                      ],
                    ),
                  ],
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

  Widget _buildPhotoEvidenceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _challanImageFile == null
              ? Colors.grey.shade200
              : AppColors.primaryStrong,
          width: _challanImageFile == null ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Challan Photo Evidence',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Upload a clear photo of the return challan document.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (_challanImageFile == null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickChallanImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryStrong,
                      side: const BorderSide(color: AppColors.primaryStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickChallanImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryStrong,
                      side: const BorderSide(color: AppColors.primaryStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    _challanImageFile!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _challanImageName ?? 'Photo Attached',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Photo Evidence Attached',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  onPressed: () {
                    setState(() {
                      _challanImageFile = null;
                      _challanImageBase64 = null;
                      _challanImageName = null;
                    });
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}
