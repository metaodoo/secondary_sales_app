import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_stock_audit.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';

class MtStockAuditCreateScreen extends StatefulWidget {
  final int? outletId;
  final String? outletName;
  final int? visitId;
  final MtStockAudit? editAudit;
  final String? initialType;

  const MtStockAuditCreateScreen({
    super.key,
    this.outletId,
    this.outletName,
    this.visitId,
    this.editAudit,
    this.initialType,
  });

  @override
  State<MtStockAuditCreateScreen> createState() => _MtStockAuditCreateScreenState();
}

class _MtStockAuditCreateScreenState extends State<MtStockAuditCreateScreen> {
  String _selectedType = 'opening_stock';
  int? _selectedCategoryId;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<MtStockAuditProduct> _availableProducts = [];
  bool _isLoadingProducts = false;
  bool _isSubmitting = false;

  // Selected audit lines: key is '${productId}_${lotId}_${index}'
  final Map<String, _AuditEntry> _entries = {};

  @override
  void initState() {
    super.initState();
    if (widget.editAudit != null) {
      _selectedType = widget.editAudit!.type;
      _notesController.text = widget.editAudit!.notes;
      for (int i = 0; i < widget.editAudit!.lines.length; i++) {
        final line = widget.editAudit!.lines[i];
        final key = '${line.productId}_${line.lotId ?? 0}_$i';
        _entries[key] = _AuditEntry(
          productId: line.productId,
          productName: line.productName,
          defaultCode: line.defaultCode,
          uomName: line.uomName,
          lotId: line.lotId,
          lotName: line.lotName,
          stockCount: line.stockCount,
        );
      }
    } else if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ModernTradeProvider>().fetchCategories();
      _loadProducts();
    });
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'opening_stock':
        return 'Opening Stock';
      case 'stock_in':
        return 'Stock In';
      case 'closing_stock':
        return 'Closing Stock';
      default:
        return 'Stock Audit';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    final effectiveOutletId = widget.outletId ?? widget.editAudit?.outletId;
    final prods = await context.read<ModernTradeProvider>().fetchAuditProducts(
      outletId: effectiveOutletId,
      search: _searchController.text.trim(),
      categoryId: _selectedCategoryId,
    );
    if (!mounted) return;

    // Track selected product IDs
    final selectedProductIds = _entries.values
        .where((e) => e.stockCount > 0)
        .map((e) => e.productId)
        .toSet();

    // Map original line ordering when editing
    final editOrderMap = <int, int>{};
    if (widget.editAudit != null) {
      for (int i = 0; i < widget.editAudit!.lines.length; i++) {
        final pId = widget.editAudit!.lines[i].productId;
        editOrderMap.putIfAbsent(pId, () => i);
      }
    }

    final sortedProds = List<MtStockAuditProduct>.from(prods);

    // If editAudit has products not present in API result, prepend them
    final returnedIds = sortedProds.map((p) => p.id).toSet();
    if (widget.editAudit != null && _selectedCategoryId == null && _searchController.text.trim().isEmpty) {
      for (final line in widget.editAudit!.lines) {
        if (!returnedIds.contains(line.productId) && line.productId > 0) {
          final missingProduct = MtStockAuditProduct(
            id: line.productId,
            name: line.productName,
            defaultCode: line.defaultCode,
            uomName: line.uomName,
            tracking: line.lotId != null ? 'lot' : 'none',
            lots: line.lotId != null
                ? [
                    MtStockAuditLot(
                      id: line.lotId!,
                      name: line.lotName ?? '',
                      expirationDate: line.expirationDate,
                    ),
                  ]
                : const [],
          );
          sortedProds.insert(0, missingProduct);
          returnedIds.add(line.productId);
        }
      }
    }

    // Sort: previously selected / counted products first, preserving edit order
    sortedProds.sort((a, b) {
      final aSelected = selectedProductIds.contains(a.id) || editOrderMap.containsKey(a.id);
      final bSelected = selectedProductIds.contains(b.id) || editOrderMap.containsKey(b.id);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      if (aSelected && bSelected) {
        final aOrder = editOrderMap[a.id] ?? 999999;
        final bOrder = editOrderMap[b.id] ?? 999999;
        final cmp = aOrder.compareTo(bOrder);
        if (cmp != 0) return cmp;
      }
      return 0;
    });

    setState(() {
      _availableProducts = sortedProds;
      _isLoadingProducts = false;
    });
  }

  void _openCategorySearchModal() {
    final categories = context.read<ModernTradeProvider>().categories;
    if (categories.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String catQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCategories = categories.where((cat) {
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
                            final isAllSelected = _selectedCategoryId == null;
                            return ListTile(
                              title: const Text('All Categories'),
                              trailing: isAllSelected
                                  ? const Icon(Icons.check, color: AppColors.primaryStrong)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = null;
                                });
                                Navigator.pop(ctx);
                                _loadProducts();
                              },
                            );
                          }
                          final cat = filteredCategories[index - 1];
                          final isSelected = _selectedCategoryId == cat.id;
                          return ListTile(
                            title: Text(cat.name),
                            trailing: isSelected
                                ? const Icon(Icons.check, color: AppColors.primaryStrong)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedCategoryId = cat.id;
                              });
                              Navigator.pop(ctx);
                              _loadProducts();
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

  double get _totalQuantity {
    return _entries.values.fold(0.0, (sum, item) => sum + item.stockCount);
  }

  String get _formattedTotalQuantity {
    final qty = _totalQuantity;
    if (qty % 1 == 0) return qty.toInt().toString();
    return qty.toString();
  }

  int get _totalLinesCount {
    return _entries.values.where((item) => item.stockCount > 0).length;
  }

  int get _selectedProductsCount {
    return _entries.values
        .where((item) => item.stockCount > 0)
        .map((item) => item.productId)
        .toSet()
        .length;
  }

  void _onProductEntriesChanged(MtStockAuditProduct prod, List<_AuditEntry> newEntries) {
    setState(() {
      _entries.removeWhere((k, v) => v.productId == prod.id);
      for (int i = 0; i < newEntries.length; i++) {
        final item = newEntries[i];
        if (item.stockCount > 0) {
          final key = '${item.productId}_${item.lotId ?? 0}_$i';
          _entries[key] = item;
        }
      }
    });
  }

  Future<void> _submitAudit({required bool confirm}) async {
    final activeLines = _entries.values.where((e) => e.stockCount > 0).toList();
    if (activeLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter stock count for at least one product.')),
      );
      return;
    }

    final effectiveOutletId = widget.outletId ?? widget.editAudit?.outletId;
    if (effectiveOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing outlet information.')),
      );
      return;
    }

    if (confirm) {
      final shouldConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Confirm Stock Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text(
            'Are you sure you want to confirm this stock audit? Once confirmed, this record cannot be edited.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Confirm'),
            ),
          ],
        ),
      );
      if (shouldConfirm != true || !mounted) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final linesPayload = activeLines.map((e) => e.toPayload()).toList();
      final provider = context.read<ModernTradeProvider>();

      if (widget.editAudit != null) {
        await provider.updateStockAudit(
          auditId: widget.editAudit!.id,
          outletId: effectiveOutletId,
          type: _selectedType,
          lines: linesPayload,
          visitId: widget.visitId ?? widget.editAudit!.visitId,
          notes: _notesController.text.trim(),
          confirm: confirm,
        );
      } else {
        await provider.createStockAudit(
          outletId: effectiveOutletId,
          type: _selectedType,
          lines: linesPayload,
          visitId: widget.visitId,
          notes: _notesController.text.trim(),
          confirm: confirm,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirm
                ? 'Stock Audit confirmed successfully!'
                : 'Stock Audit saved as draft.',
          ),
          backgroundColor: confirm ? const Color(0xFF10B981) : AppColors.primaryStrong,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSaveDraft = context.select<AuthProvider, bool>(
      (auth) => auth.access.allows(AppAction.mtSecStockAuditCreate),
    );
    final canConfirm = context.select<AuthProvider, bool>(
      (auth) => auth.access.allows(AppAction.mtSecStockAuditConfirm),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: widget.editAudit != null
                  ? 'Edit ${_typeLabel(_selectedType)}'
                  : 'New ${_typeLabel(_selectedType)}',
              subtitle: widget.outletName ?? widget.editAudit?.outletName ?? 'Modern Trade',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Product Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _loadProducts(),
                decoration: InputDecoration(
                  hintText: 'Search products by name or code...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    onPressed: _loadProducts,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            // Category Bar Selector with Search Button
            Consumer<ModernTradeProvider>(
              builder: (context, mtProvider, _) {
                if (mtProvider.categories.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _openCategorySearchModal,
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
                              Icon(Icons.filter_list, size: 16, color: AppColors.primaryStrong),
                              SizedBox(width: 4),
                              Text(
                                'Category',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryStrong,
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
                            itemCount: mtProvider.categories.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final isSelected = _selectedCategoryId == null;
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
                                      setState(() => _selectedCategoryId = null);
                                      _loadProducts();
                                    },
                                  ),
                                );
                              }
                              final cat = mtProvider.categories[index - 1];
                              final isSelected = _selectedCategoryId == cat.id;
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
                                    setState(() => _selectedCategoryId = cat.id);
                                    _loadProducts();
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
              },
            ),
            // Product Count Bar
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_availableProducts.length} Products Shown',
                      style: const TextStyle(
                        color: AppColors.primaryStrong,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (_selectedProductsCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFC8E6C9)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 13, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 4),
                          Text(
                            '$_selectedProductsCount Selected',
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_selectedCategoryId != null || _searchController.text.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = null;
                          _searchController.clear();
                        });
                        _loadProducts();
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.clear, size: 14, color: AppColors.textSecondary),
                          SizedBox(width: 2),
                          Text(
                            'Clear filter',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Product List with Quantity Controls
            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _availableProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'No products found.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _availableProducts.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final prod = _availableProducts[index];
                            final prodEntries = _entries.values
                                .where((e) => e.productId == prod.id && e.stockCount > 0)
                                .toList();
                            return _ProductAuditCard(
                              key: ValueKey('prod_${prod.id}'),
                              product: prod,
                              entries: prodEntries,
                              onEntriesChanged: (updatedEntries) {
                                _onProductEntriesChanged(prod, updatedEntries);
                              },
                            );
                          },
                        ),
            ),
            // Bottom Summary & Actions Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFDDE6F2))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Items: $_totalLinesCount',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Total Qty: $_formattedTotalQuantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primaryStrong,
                        ),
                      ),
                    ],
                  ),
                  if (canSaveDraft || canConfirm) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (canSaveDraft)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting ? null : () => _submitAudit(confirm: false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primaryStrong),
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'Save as Draft',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStrong),
                              ),
                            ),
                          ),
                        if (canSaveDraft && canConfirm) const SizedBox(width: 12),
                        if (canConfirm)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : () => _submitAudit(confirm: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Confirm Audit',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditEntry {
  final int productId;
  final String productName;
  final String? defaultCode;
  final String? uomName;
  final int? lotId;
  final String? lotName;
  final double stockCount;

  _AuditEntry({
    required this.productId,
    required this.productName,
    this.defaultCode,
    this.uomName,
    this.lotId,
    this.lotName,
    required this.stockCount,
  });

  Map<String, dynamic> toPayload() {
    return {
      'product_id': productId,
      if (lotId != null) 'lot_id': lotId,
      'stock_count': stockCount,
    };
  }
}

class _LotRowData {
  int? lotId;
  String? lotName;
  late TextEditingController controller;
  late FocusNode focusNode;

  _LotRowData({
    this.lotId,
    this.lotName,
    double initialQty = 0.0,
  }) {
    controller = TextEditingController(text: _formatQtyStatic(initialQty));
    focusNode = FocusNode();
  }

  static String _formatQtyStatic(double val) {
    if (val <= 0) return '';
    if (val % 1 == 0) return val.toInt().toString();
    return val.toString();
  }

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _ProductAuditCard extends StatefulWidget {
  final MtStockAuditProduct product;
  final List<_AuditEntry> entries;
  final void Function(List<_AuditEntry> entries) onEntriesChanged;

  const _ProductAuditCard({
    super.key,
    required this.product,
    required this.entries,
    required this.onEntriesChanged,
  });

  @override
  State<_ProductAuditCard> createState() => _ProductAuditCardState();
}

class _ProductAuditCardState extends State<_ProductAuditCard> {
  final List<_LotRowData> _lotRows = [];

  @override
  void initState() {
    super.initState();
    _initRows();
  }

  void _initRows() {
    _lotRows.clear();
    if (widget.entries.isNotEmpty) {
      for (final entry in widget.entries) {
        final row = _LotRowData(
          lotId: entry.lotId,
          lotName: entry.lotName,
          initialQty: entry.stockCount,
        );
        _attachFocusListener(row);
        _lotRows.add(row);
      }
    } else {
      if (widget.product.lots.isNotEmpty) {
        final row = _LotRowData(
          lotId: widget.product.lots.first.id,
          lotName: widget.product.lots.first.name,
          initialQty: 0.0,
        );
        _attachFocusListener(row);
        _lotRows.add(row);
      } else {
        final row = _LotRowData(
          lotId: null,
          lotName: null,
          initialQty: 0.0,
        );
        _attachFocusListener(row);
        _lotRows.add(row);
      }
    }
  }

  void _attachFocusListener(_LotRowData row) {
    row.focusNode.addListener(() {
      if (!row.focusNode.hasFocus) {
        final text = row.controller.text.trim();
        if (text.isEmpty) {
          _notifyChanged();
        } else {
          final parsed = double.tryParse(text) ?? 0.0;
          row.controller.text = _formatQty(parsed);
          _notifyChanged();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ProductAuditCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasFocus = _lotRows.any((r) => r.focusNode.hasFocus);
    if (!hasFocus) {
      final currentEntries = _buildCurrentEntries();
      bool isDifferent = currentEntries.length != widget.entries.length;
      if (!isDifferent) {
        for (int i = 0; i < currentEntries.length; i++) {
          if (currentEntries[i].lotId != widget.entries[i].lotId ||
              currentEntries[i].stockCount != widget.entries[i].stockCount) {
            isDifferent = true;
            break;
          }
        }
      }
      if (isDifferent) {
        for (final r in _lotRows) {
          r.dispose();
        }
        _initRows();
      }
    }
  }

  @override
  void dispose() {
    for (final r in _lotRows) {
      r.dispose();
    }
    super.dispose();
  }

  String _formatQty(double val) {
    if (val <= 0) return '';
    if (val % 1 == 0) return val.toInt().toString();
    return val.toString();
  }

  List<_AuditEntry> _buildCurrentEntries() {
    final List<_AuditEntry> list = [];
    for (final row in _lotRows) {
      final text = row.controller.text.trim();
      final qty = double.tryParse(text) ?? 0.0;
      if (qty > 0) {
        list.add(_AuditEntry(
          productId: widget.product.id,
          productName: widget.product.name,
          defaultCode: widget.product.defaultCode,
          uomName: widget.product.uomName,
          lotId: row.lotId,
          lotName: row.lotName,
          stockCount: qty,
        ));
      }
    }
    return list;
  }

  void _notifyChanged() {
    widget.onEntriesChanged(_buildCurrentEntries());
  }

  void _setQty(_LotRowData row, double val) {
    final clamped = val < 0 ? 0.0 : val;
    row.controller.text = _formatQty(clamped);
    _notifyChanged();
    setState(() {});
  }

  void _addLotRow() {
    if (widget.product.lots.isEmpty) return;
    final selectedLotIds = _lotRows.map((r) => r.lotId).toSet();
    final availableLot = widget.product.lots.where((l) => !selectedLotIds.contains(l.id)).firstOrNull ??
        widget.product.lots.first;

    final newRow = _LotRowData(
      lotId: availableLot.id,
      lotName: availableLot.name,
      initialQty: 0.0,
    );
    _attachFocusListener(newRow);
    _lotRows.add(newRow);
    setState(() {});
  }

  void _removeLotRow(int index) {
    if (index >= 0 && index < _lotRows.length) {
      final removed = _lotRows.removeAt(index);
      removed.dispose();
      _notifyChanged();
      setState(() {});
    }
  }

  double get _totalCardQuantity {
    return _lotRows.fold(0.0, (sum, r) {
      final qty = double.tryParse(r.controller.text.trim()) ?? 0.0;
      return sum + qty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasLots = widget.product.lots.isNotEmpty;
    final totalQty = _totalCardQuantity;
    final hasQty = totalQty > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasQty ? AppColors.primaryStrong : AppColors.borderSoft,
          width: hasQty ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Info Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (widget.product.defaultCode != null && widget.product.defaultCode!.isNotEmpty)
                      Text(
                        'Code: ${widget.product.defaultCode}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (hasQty)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryTint),
                  ),
                  child: Text(
                    'Total: ${_formatQty(totalQty)} ${widget.product.uomName ?? ""}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryStrong,
                    ),
                  ),
                ),
              if (widget.product.uomName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.product.uomName!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),

          // Body: Lot Rows OR Single Count Row
          if (hasLots) ...[
            const SizedBox(height: 8),
            ...List.generate(_lotRows.length, (index) {
              final row = _lotRows[index];
              final rowQty = double.tryParse(row.controller.text.trim()) ?? 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: rowQty > 0
                        ? AppColors.primaryStrong.withValues(alpha: 0.35)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.borderSoft),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: row.lotId,
                                hint: const Text('Select Lot & Expiry', style: TextStyle(fontSize: 12)),
                                items: widget.product.lots.map((lot) {
                                  return DropdownMenuItem<int>(
                                    value: lot.id,
                                    child: Text(
                                      lot.displayName,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() {
                                    row.lotId = val;
                                    final selectedLot = widget.product.lots.firstWhere((l) => l.id == val);
                                    row.lotName = selectedLot.name;
                                  });
                                  _notifyChanged();
                                },
                              ),
                            ),
                          ),
                        ),
                        if (_lotRows.length > 1) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _removeLotRow(index),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFEF4444),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Count:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.primaryStrong),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                final current = double.tryParse(row.controller.text.trim()) ?? 0.0;
                                if (current > 0) _setQty(row, current - 1);
                              },
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 70,
                              height: 36,
                              child: TextField(
                                controller: row.controller,
                                focusNode: row.focusNode,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.borderSoft),
                                  ),
                                ),
                                onChanged: (val) {
                                  _notifyChanged();
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryStrong),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                final current = double.tryParse(row.controller.text.trim()) ?? 0.0;
                                _setQty(row, current + 1);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            // "+ Add Lot / Batch" Button
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: _addLotRow,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryTint),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: AppColors.primaryStrong),
                      SizedBox(width: 4),
                      Text(
                        'Add Lot / Batch',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // Single Count row for products without lots
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Count:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.primaryStrong),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        if (_lotRows.isEmpty) return;
                        final current = double.tryParse(_lotRows.first.controller.text.trim()) ?? 0.0;
                        if (current > 0) _setQty(_lotRows.first, current - 1);
                      },
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 70,
                      height: 36,
                      child: TextField(
                        controller: _lotRows.isNotEmpty ? _lotRows.first.controller : null,
                        focusNode: _lotRows.isNotEmpty ? _lotRows.first.focusNode : null,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderSoft),
                          ),
                        ),
                        onChanged: (val) {
                          _notifyChanged();
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryStrong),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        if (_lotRows.isEmpty) return;
                        final current = double.tryParse(_lotRows.first.controller.text.trim()) ?? 0.0;
                        _setQty(_lotRows.first, current + 1);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
