import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/modern_trade/mt_return_provider.dart';

class MtReturnProductSelectionSheet extends StatefulWidget {
  final String returnBucket;

  const MtReturnProductSelectionSheet({
    super.key,
    required this.returnBucket,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String returnBucket,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MtReturnProductSelectionSheet(returnBucket: returnBucket),
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

  Map<String, dynamic>? _selectedProduct;
  int? _selectedLotId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MtReturnProvider>().fetchReturnProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _saleableQtyController.dispose();
    _nonSaleableQtyController.dispose();
    _qualityQtyController.dispose();
    super.dispose();
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

    final saleableQty = double.tryParse(_saleableQtyController.text) ?? 0.0;
    final nonSaleableQty = double.tryParse(_nonSaleableQtyController.text) ?? 0.0;
    final qualityQty = double.tryParse(_qualityQtyController.text) ?? 0.0;

    if (widget.returnBucket == 'saleable') {
      if (saleableQty <= 0 && nonSaleableQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter at least Saleable or Non-Saleable quantity')),
        );
        return;
      }
    } else {
      if (nonSaleableQty <= 0 && qualityQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter at least Non-Saleable or Quality quantity')),
        );
        return;
      }
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
    final isSaleable = widget.returnBucket == 'saleable';
    final provider = context.watch<MtReturnProvider>();

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
                  _selectedProduct == null ? 'Select Product' : 'Configure Quantities',
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
                : _buildQuantityConfigurator(provider, isSaleable),
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
            decoration: InputDecoration(
              hintText: 'Search products by name or code...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => provider.fetchReturnProducts(search: val),
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

  Widget _buildQuantityConfigurator(MtReturnProvider provider, bool isSaleable) {
    final p = _selectedProduct!;
    final name = p['name']?.toString() ?? '';
    final code = p['default_code']?.toString() ?? '';
    final uom = p['uom'] is Map ? p['uom']['name']?.toString() ?? 'Unit' : 'Unit';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Product Summary Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryStrong.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryStrong.withOpacity(0.2)),
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
          const Text(
            'Lot / Serial Number (Optional)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          if (provider.isLoadingLots)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else
            DropdownButtonFormField<int?>(
              value: _selectedLotId,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Select lot number...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('No specific lot', style: TextStyle(color: Colors.grey)),
                ),
                ...provider.availableLots.map((lot) {
                  final id = lot['id'] as int?;
                  final lotName = lot['name']?.toString() ?? '';
                  final exp = lot['expiration_date']?.toString();
                  return DropdownMenuItem<int?>(
                    value: id,
                    child: Text(
                      exp != null && exp.isNotEmpty ? '$lotName (Exp: $exp)' : lotName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _selectedLotId = val),
            ),
          const SizedBox(height: 20),

          // Quantities Fields
          if (isSaleable) ...[
            _buildQtyInput(
              label: 'Saleable Quantity',
              controller: _saleableQtyController,
              color: Colors.teal,
              hint: 'Good condition units for restock',
            ),
            const SizedBox(height: 14),
            _buildQtyInput(
              label: 'Non-Saleable Quantity',
              controller: _nonSaleableQtyController,
              color: Colors.orange,
              hint: 'Damaged/Scrap units',
            ),
          ] else ...[
            _buildQtyInput(
              label: 'Non-Saleable Quantity',
              controller: _nonSaleableQtyController,
              color: Colors.orange,
              hint: 'Damaged/Broken units for scrap',
            ),
            const SizedBox(height: 14),
            _buildQtyInput(
              label: 'Quality Defect Quantity',
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
              child: const Text(
                'Add Line to Return',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
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
