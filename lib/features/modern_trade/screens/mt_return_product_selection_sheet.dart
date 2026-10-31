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
  final int? outletId;

  const MtReturnProductSelectionSheet({
    super.key,
    required this.returnBucket,
    this.initialLine,
    this.state,
    this.outletId,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String returnBucket,
    Map<String, dynamic>? initialLine,
    String? state,
    int? outletId,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MtReturnProductSelectionSheet(
        returnBucket: returnBucket,
        initialLine: initialLine,
        state: state,
        outletId: outletId,
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
  final TextEditingController _notesController = TextEditingController();
  Timer? _searchDebounce;

  Map<String, dynamic>? _selectedProduct;
  int? _selectedLotId;
  int? _selectedAppCategoryId;

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
      _notesController.text = line['notes']?.toString() ?? line['note']?.toString() ?? '';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MtReturnProvider>().fetchAppCategories();
        final prodId = _selectedProduct?['id'] as int?;
        if (prodId != null) {
          context.read<MtReturnProvider>().fetchProductLots(
                prodId,
                returnBucket: widget.returnBucket,
              );
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MtReturnProvider>().fetchAppCategories();
        context.read<MtReturnProvider>().fetchReturnProducts(
          outletId: widget.outletId,
        );
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
    _notesController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<MtReturnProvider>().fetchReturnProducts(
          search: val.trim(),
          appCategoryId: _selectedAppCategoryId,
          outletId: widget.outletId,
        );
      }
    });
  }

  void _openCategorySearchModal(MtReturnProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String catQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCategories = provider.appCategories.where((cat) {
              return cat.name.toLowerCase().contains(catQuery.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Select Category',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            onChanged: (val) {
                              setModalState(() {
                                catQuery = val.trim();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search category...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.borderSoft),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filteredCategories.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final isAllSelected = _selectedAppCategoryId == null;
                            return ListTile(
                              title: const Text('All Categories'),
                              trailing: isAllSelected
                                  ? const Icon(Icons.check, color: AppColors.primaryStrong)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedAppCategoryId = null;
                                });
                                Navigator.pop(ctx);
                                provider.fetchReturnProducts(
                                  search: _searchController.text.trim(),
                                  appCategoryId: null,
                                  outletId: widget.outletId,
                                );
                              },
                            );
                          }
                          final cat = filteredCategories[index - 1];
                          final isSelected = _selectedAppCategoryId == cat.id;
                          return ListTile(
                            title: Text(cat.name),
                            trailing: isSelected
                                ? const Icon(Icons.check, color: AppColors.primaryStrong)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedAppCategoryId = cat.id;
                              });
                              Navigator.pop(ctx);
                              provider.fetchReturnProducts(
                                search: _searchController.text.trim(),
                                appCategoryId: cat.id,
                                outletId: widget.outletId,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  bool get _isTracked {
    if (_selectedProduct == null) return false;
    final tracking = _selectedProduct!['tracking']?.toString().toLowerCase().trim();
    return tracking == 'lot' || tracking == 'serial' || (tracking != null && tracking.isNotEmpty && tracking != 'none' && tracking != 'false');
  }

  void _onSelectProduct(Map<String, dynamic> product) {
    setState(() {
      _selectedProduct = product;
      _selectedLotId = null;
    });
    final prodId = product['id'] as int?;
    if (prodId != null) {
      context.read<MtReturnProvider>().fetchProductLots(
            prodId,
            returnBucket: widget.returnBucket,
          );
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

    if (_isTracked && (_selectedLotId == null || _selectedLotId == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: const Text('Lot selection is mandatory for this tracked product.'),
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
      'notes': _notesController.text.trim(),
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
                  tooltip: 'Close',
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
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        provider.fetchReturnProducts(
                          search: '',
                          appCategoryId: _selectedAppCategoryId,
                          outletId: widget.outletId,
                        );
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
        if (provider.appCategories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _openCategorySearchModal(provider),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primaryTint),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 16, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.zero,
                      itemCount: provider.appCategories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final bool isSelected = _selectedAppCategoryId == null;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: const Text('All Categories'),
                              selected: isSelected,
                              selectedColor: AppColors.primaryStrong,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: isSelected ? AppColors.primaryStrong : AppColors.borderSoft,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedAppCategoryId = null;
                                });
                                provider.fetchReturnProducts(
                                  search: _searchController.text.trim(),
                                  appCategoryId: null,
                                  outletId: widget.outletId,
                                );
                              },
                            ),
                          );
                        }
                        final cat = provider.appCategories[index - 1];
                        final bool isSelected = _selectedAppCategoryId == cat.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cat.name),
                            selected: isSelected,
                            selectedColor: AppColors.primaryStrong,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: isSelected ? AppColors.primaryStrong : AppColors.borderSoft,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedAppCategoryId = cat.id;
                              });
                              provider.fetchReturnProducts(
                                search: _searchController.text.trim(),
                                appCategoryId: cat.id,
                                outletId: widget.outletId,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
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
                        final price = (p['has_reward_discount'] == true && p['reward_price'] != null)
                            ? (p['reward_price'] as num).toDouble()
                            : (p['list_price'] as num?)?.toDouble();
                        final priceStr = price != null && price > 0 ? ' • ৳${price.toStringAsFixed(2)}' : '';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                          title: Text(
                            name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            code.isNotEmpty ? 'Code: $code • UoM: $uom$priceStr' : 'UoM: $uom$priceStr',
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
                  onPressed: () => setState(() {
                    _selectedProduct = null;
                    _selectedLotId = null;
                  }),
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
                _isTracked
                    ? 'Lot / Serial Number (Required)'
                    : 'Lot / Serial Number (Optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isTracked
                      ? const Color(0xFFDC2626)
                      : AppColors.textPrimary,
                ),
              ),
              if (_isTracked)
                const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          if (provider.isLoadingLots)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else if (_isTracked && provider.availableLots.isEmpty)
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
              hintText: _isTracked
                  ? 'Select lot number (Required) *'
                  : 'Select lot number (Optional)...',
              allowClear: !_isTracked,
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
          const SizedBox(height: 14),

          // Remarks / Notes
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.notes_rounded, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    'Line Remarks / Notes (optional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Enter reason or remark for this item...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

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
