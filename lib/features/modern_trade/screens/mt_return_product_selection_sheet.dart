import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/searchable_lot_selector.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/modern_trade/mt_return_provider.dart';

class MtReturnProductSelectionSheet extends StatefulWidget {
  final String returnBucket;
  final Map<String, dynamic>? initialLine;
  final String? state;

  const MtReturnProductSelectionSheet({
    super.key,
    required this.returnBucket,
    this.initialLine,
    this.state,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String returnBucket,
    Map<String, dynamic>? initialLine,
    String? state,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MtReturnProductSelectionSheet(
        returnBucket: returnBucket,
        initialLine: initialLine,
        state: state,
      ),
    );
  }

  @override
  State<MtReturnProductSelectionSheet> createState() => _MtReturnProductSelectionSheetState();
}

class _MtReturnProductSelectionSheetState extends State<MtReturnProductSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _saleableQtyController = TextEditingController(text: '0');
  final TextEditingController _nonSaleableQtyController = TextEditingController(text: '0');
  final TextEditingController _qualityQtyController = TextEditingController(text: '0');
  Timer? _searchDebounce;

  Map<String, dynamic>? _selectedProduct;
  int? _selectedLotId;

  @override
  void initState() {
    super.initState();
    if (widget.initialLine != null) {
      final line = widget.initialLine!;
      _selectedProduct = line['product'] as Map<String, dynamic>?;
      _selectedLotId = line['lot_id'] as int?;

      final sQty = (line['saleable_qty'] as num?)?.toDouble() ?? 0.0;
      final nsQty = (line['non_saleable_qty'] as num?)?.toDouble() ?? 0.0;
      final qQty = (line['quality_qty'] as num?)?.toDouble() ?? 0.0;

      _saleableQtyController.text = sQty > 0
          ? sQty.toStringAsFixed(sQty.truncateToDouble() == sQty ? 0 : 2)
          : '0';
      _nonSaleableQtyController.text = nsQty > 0
          ? nsQty.toStringAsFixed(nsQty.truncateToDouble() == nsQty ? 0 : 2)
          : '0';
      _qualityQtyController.text = qQty > 0
          ? qQty.toStringAsFixed(qQty.truncateToDouble() == qQty ? 0 : 2)
          : '0';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final prodId = _selectedProduct?['id'] as int?;
        if (prodId != null) {
          context.read<MtReturnProvider>().fetchProductLots(prodId);
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MtReturnProvider>().fetchReturnProducts();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _saleableQtyController.dispose();
    _nonSaleableQtyController.dispose();
    _qualityQtyController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<MtReturnProvider>().fetchReturnProducts(search: val.trim());
      }
    });
  }

  void _onSelectProduct(Map<String, dynamic> product) {
    setState(() {
      _selectedProduct = product;
      _selectedLotId = null;
    });
    final prodId = product['id'] as int?;
    if (prodId != null) {
      context.read<MtReturnProvider>().fetchProductLots(prodId);
    }
  }

  void _onSubmit() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }

    final isSaleable = widget.returnBucket == 'saleable';
    final isNonSaleable = widget.returnBucket == 'non_saleable';
    final isQuality = widget.returnBucket == 'quality';

    final auth = context.read<AuthProvider>();
    final isSegregationStage = widget.state != null &&
        widget.state!.toLowerCase() != 'kao' &&
        widget.state!.toLowerCase() != 'dm';

    final showSaleable = isSaleable;
    final showNonSaleable = (isSaleable && isSegregationStage && auth.canDo(AppAction.mtReturnsSegregateSaleable)) ||
        isNonSaleable ||
        (isQuality && isSegregationStage && auth.canDo(AppAction.mtReturnsSegregateQuality));
    final showQuality = (isNonSaleable && isSegregationStage && auth.canDo(AppAction.mtReturnsSegregateNonSaleable)) ||
        isQuality;

    final saleableQty = showSaleable ? (double.tryParse(_saleableQtyController.text) ?? 0.0) : 0.0;
    final nonSaleableQty = showNonSaleable ? (double.tryParse(_nonSaleableQtyController.text) ?? 0.0) : 0.0;
    final qualityQty = showQuality ? (double.tryParse(_qualityQtyController.text) ?? 0.0) : 0.0;

    if (isSaleable) {
      if (saleableQty <= 0 && (!showNonSaleable || nonSaleableQty <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid Saleable quantity')),
        );
        return;
      }
    } else if (isQuality) {
      if (qualityQty <= 0 && (!showNonSaleable || nonSaleableQty <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid Quality quantity')),
        );
        return;
      }
    } else {
      if (nonSaleableQty <= 0 && (!showQuality || qualityQty <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid Non-Saleable quantity')),
        );
        return;
      }
    }

    final tracking = _selectedProduct?['tracking']?.toString();
    final isTracked = tracking == 'lot' || tracking == 'serial';

    if (isTracked && (_selectedLotId == null || _selectedLotId == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please select a Lot / Serial number for this tracked product.'),
        ),
      );
      return;
    }

    final provider = context.read<MtReturnProvider>();
    Map<String, dynamic>? selectedLot;
    if (_selectedLotId != null) {
      try {
        selectedLot = provider.availableLots.firstWhere((l) => l['id'] == _selectedLotId);
      } catch (_) {
        selectedLot = null;
      }
    }

    Navigator.of(context).pop({
      'product': _selectedProduct,
      'product_id': _selectedProduct!['id'],
      'lot': selectedLot,
      'lot_id': _selectedLotId,
      'saleable_qty': saleableQty,
      'non_saleable_qty': nonSaleableQty,
      'quality_qty': qualityQty,
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MtReturnProvider>();
    final auth = context.watch<AuthProvider>();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedProduct == null
                      ? 'Select Product'
                      : (widget.initialLine != null ? 'Edit Return Product' : 'Configure Quantities'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Body
          Expanded(
            child: _selectedProduct == null
                ? _buildProductPicker(provider)
                : _buildQuantityConfigurator(provider, auth),
          ),
        ],
      ),
    );
  }

  Widget _buildProductPicker(MtReturnProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search products by name or code...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        provider.fetchReturnProducts(search: '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: provider.isLoadingProducts
              ? const Center(child: CircularProgressIndicator())
              : provider.availableProducts.isEmpty
                  ? Center(
                      child: Text(
                        'No products found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: provider.availableProducts.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final p = provider.availableProducts[index];
                        final name = p['name']?.toString() ?? '';
                        final code = p['default_code']?.toString() ?? '';
                        final uom = p['uom'] is Map ? p['uom']['name']?.toString() ?? 'Unit' : 'Unit';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                          title: Text(
                            name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            code.isNotEmpty ? 'Code: $code • UoM: $uom' : 'UoM: $uom',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                          onTap: () => _onSelectProduct(p),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildQuantityConfigurator(MtReturnProvider provider, AuthProvider auth) {
    final p = _selectedProduct!;
    final name = p['name']?.toString() ?? '';
    final code = p['default_code']?.toString() ?? '';
    final uom = p['uom'] is Map ? p['uom']['name']?.toString() ?? 'Unit' : 'Unit';

    final isSaleable = widget.returnBucket == 'saleable';
    final isNonSaleable = widget.returnBucket == 'non_saleable';
    final isQuality = widget.returnBucket == 'quality';

    final isSegregationStage = widget.state != null &&
        widget.state!.toLowerCase() != 'kao' &&
        widget.state!.toLowerCase() != 'dm';

    final showSaleable = isSaleable;
    final showNonSaleable = (isSaleable && isSegregationStage && auth.canDo(AppAction.mtReturnsSegregateSaleable)) ||
        isNonSaleable ||
        (isQuality && isSegregationStage && auth.canDo(AppAction.mtReturnsSegregateQuality));
    final showQuality = (isNonSaleable && isSegregationStage && auth.canDo(AppAction.mtReturnsSegregateNonSaleable)) ||
        isQuality;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Product Summary Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryStrong.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryStrong.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code.isNotEmpty ? 'Code: $code • UoM: $uom' : 'UoM: $uom',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedProduct = null),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Lot Picker
          Row(
            children: [
              Text(
                (_selectedProduct?['tracking'] == 'lot' || _selectedProduct?['tracking'] == 'serial')
                    ? 'Lot / Serial Number (Required)'
                    : 'Lot / Serial Number (Optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: (_selectedProduct?['tracking'] == 'lot' || _selectedProduct?['tracking'] == 'serial')
                      ? const Color(0xFFDC2626)
                      : AppColors.textPrimary,
                ),
              ),
              if (_selectedProduct?['tracking'] == 'lot' || _selectedProduct?['tracking'] == 'serial')
                const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          if (provider.isLoadingLots)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else if ((_selectedProduct?['tracking'] == 'lot' || _selectedProduct?['tracking'] == 'serial') && provider.availableLots.isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No unexpired lots found for this tracked product.',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else
            GenericSearchableLotSelector<Map<String, dynamic>>(
              selectedItem: _selectedLotId != null
                  ? provider.availableLots.firstWhere(
                      (l) => l['id'] == _selectedLotId,
                      orElse: () => {'id': _selectedLotId, 'name': 'Lot #$_selectedLotId'},
                    )
                  : null,
              items: provider.availableLots,
              getLabel: (lot) => lot['name']?.toString() ?? '',
              getSubtitle: (lot) => lot['expiration_date'] != null && lot['expiration_date'].toString().isNotEmpty
                  ? 'Exp: ${lot['expiration_date']}'
                  : null,
              modalTitle: 'Select Return Lot',
              hintText: (_selectedProduct?['tracking'] == 'lot' || _selectedProduct?['tracking'] == 'serial')
                  ? 'Select lot number *'
                  : 'Select lot number...',
              allowClear: !(_selectedProduct?['tracking'] == 'lot' || _selectedProduct?['tracking'] == 'serial'),
              clearLabel: 'No specific lot',
              onChanged: (val) {
                setState(() => _selectedLotId = val != null ? val['id'] as int? : null);
              },
            ),
          const SizedBox(height: 20),

          // Quantities Fields
          if (showSaleable) ...[
            _buildQtyInput(
              label: 'Saleable Quantity',
              controller: _saleableQtyController,
              color: Colors.teal,
              hint: 'Good condition units for restock',
            ),
          ],
          if (showSaleable && showNonSaleable) const SizedBox(height: 14),
          if (showNonSaleable) ...[
            _buildQtyInput(
              label: isSaleable ? 'Non-Saleable (Segregation)' : 'Non-Saleable Quantity',
              controller: _nonSaleableQtyController,
              color: Colors.orange,
              hint: 'Damaged/Broken units for scrap',
            ),
          ],
          if ((showSaleable || showNonSaleable) && showQuality) const SizedBox(height: 14),
          if (showQuality) ...[
            _buildQtyInput(
              label: isNonSaleable ? 'Quality Defect (Segregation)' : 'Quality Defect Quantity',
              controller: _qualityQtyController,
              color: Colors.purple,
              hint: 'Units returned for quality inspection',
            ),
          ],

          const SizedBox(height: 28),

          // Add Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryStrong,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                widget.initialLine != null ? 'Update Return Line' : 'Add Line to Return',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyInput({
    required String label,
    required TextEditingController controller,
    required Color color,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
