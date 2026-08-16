import 'dart:async';
import 'package:secondary_sales/core/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/sales/order_line_entry.dart';
import 'package:secondary_sales/data/models/sales/product.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';

class ProductSelectionScreen extends StatefulWidget {
  final String saleType;
  final int? partnerId;
  const ProductSelectionScreen({
    super.key,
    this.saleType = 'primary',
    this.partnerId,
  });

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  final Map<int, OrderLineEntry> _selectedLines = {};
  bool _inStockOnly = false;
  String _sortBy = 'name_asc';
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PrimarySaleProvider>();
      provider.fetchProductCategories();
      _fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _fetchProducts() {
    context.read<PrimarySaleProvider>().searchProducts(
      _searchController.text,
      saleType: widget.saleType,
      partnerId: widget.partnerId,
      categoryId: _selectedCategoryId,
      inStockOnly: _inStockOnly,
      sortBy: _sortBy,
    );
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchProducts();
    });
  }

  void _finishSelection() {
    if (_selectedLines.isEmpty) return;
    Navigator.pop(context, _selectedLines.values.toList());
  }

  void _toggleSelect(Product product) {
    setState(() {
      final entry = _selectedLines[product.id];
      if (entry != null && entry.isSelected) {
        _selectedLines.remove(product.id);
      } else {
        _selectedLines[product.id] = OrderLineEntry(
          product: product,
          quantity: 1,
          damagedQty: 0,
          qualityQty: 0,
        );
      }
    });
  }

  void _updateQuantity(
    Product product, {
    int? quantity,
    int? damagedQty,
    int? qualityQty,
  }) {
    setState(() {
      final entry = _selectedLines[product.id] ??
          OrderLineEntry(
            product: product,
            quantity: 0,
            damagedQty: 0,
            qualityQty: 0,
          );

      if (quantity != null) entry.quantity = quantity < 0 ? 0 : quantity;
      if (damagedQty != null) entry.damagedQty = damagedQty < 0 ? 0 : damagedQty;
      if (qualityQty != null) entry.qualityQty = qualityQty < 0 ? 0 : qualityQty;

      if (entry.isSelected) {
        _selectedLines[product.id] = entry;
      } else {
        _selectedLines.remove(product.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrimarySaleProvider>();
    final int selectedItemsCount = _selectedLines.length;
    final int totalUnits = _selectedLines.values.fold(
      0,
      (sum, line) => sum + line.totalQty,
    );
    final bool hasItems = selectedItemsCount > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.saleType == 'secondary'
              ? 'Select Secondary Products'
              : 'Select Primary Products',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Area
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search products by name or code...',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),

            // Category Bar Selector
            if (provider.categories.isNotEmpty) ...[
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: provider.categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final bool isSelected = _selectedCategoryId == null;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('All Categories'),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.borderSoft,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedCategoryId = null;
                            });
                            _fetchProducts();
                          },
                        ),
                      );
                    }
                    final cat = provider.categories[index - 1];
                    final bool isSelected = _selectedCategoryId == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cat.name),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.borderSoft,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedCategoryId = cat.id;
                          });
                          _fetchProducts();
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Product Count & Sorting Controls Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Product Count Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${provider.totalProductCount > 0 ? provider.totalProductCount : provider.products.length} Products',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // In Stock Filter
                  FilterChip(
                    selected: _inStockOnly,
                    avatar: Icon(
                      _inStockOnly
                          ? Icons.check_circle
                          : Icons.inventory_2_outlined,
                      size: 15,
                      color: _inStockOnly ? Colors.white : AppColors.primary,
                    ),
                    label: Text(
                      widget.saleType == 'secondary'
                          ? 'Stock > 0'
                          : 'In Stock Only',
                      style: TextStyle(
                        color: _inStockOnly
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _inStockOnly
                          ? AppColors.primary
                          : AppColors.borderSoft,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _inStockOnly = selected;
                      });
                      _fetchProducts();
                    },
                  ),
                  const SizedBox(width: 4),
                  // Sort Dropdown Menu
                  PopupMenuButton<String>(
                    initialValue: _sortBy,
                    icon: const Icon(Icons.sort, color: AppColors.textPrimary, size: 20),
                    tooltip: 'Sort Products',
                    onSelected: (value) {
                      setState(() {
                        _sortBy = value;
                      });
                      _fetchProducts();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'name_asc',
                        child: Text('Name (A to Z)'),
                      ),
                      PopupMenuItem(
                        value: 'qty_desc',
                        child: Text('Available Qty (High → Low)'),
                      ),
                      PopupMenuItem(
                        value: 'qty_asc',
                        child: Text('Available Qty (Low → High)'),
                      ),
                      PopupMenuItem(
                        value: 'expiry_asc',
                        child: Text('Expiry Date (Earliest First)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Products list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _fetchProducts();
                },
                child: provider.isLoading && provider.products.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : provider.products.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 100),
                          Center(
                            child: Text(
                              'No products found',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        itemCount: provider.products.length,
                        itemBuilder: (context, index) {
                          final product = provider.products[index];
                          final lineEntry = _selectedLines[product.id];
                          return ProductSelectionCard(
                            product: product,
                            lineEntry: lineEntry,
                            saleType: widget.saleType,
                            onToggleSelect: () => _toggleSelect(product),
                            onQuantityChanged: (qty, damaged, quality) {
                              _updateQuantity(
                                product,
                                quantity: qty,
                                damagedQty: damaged,
                                qualityQty: quality,
                              );
                            },
                          );
                        },
                      ),
              ),
            ),

            // Bottom Confirm Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderSoft)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: hasItems ? _finishSelection : null,
                  icon: Icon(
                    Icons.shopping_cart_outlined,
                    color: hasItems ? Colors.white : AppColors.textSecondary,
                  ),
                  label: Text(
                    hasItems
                        ? 'Add $selectedItemsCount Items ($totalUnits Units)'
                        : 'Select Items',
                    style: TextStyle(
                      color: hasItems ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasItems
                        ? AppColors.primary
                        : AppColors.borderSoft,
                    disabledBackgroundColor: AppColors.borderMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductSelectionCard extends StatelessWidget {
  const ProductSelectionCard({
    super.key,
    required this.product,
    required this.lineEntry,
    required this.onQuantityChanged,
    required this.onToggleSelect,
    this.saleType = 'primary',
  });

  final Product product;
  final OrderLineEntry? lineEntry;
  final Function(int orderQty, int damagedQty, int qualityQty) onQuantityChanged;
  final VoidCallback onToggleSelect;
  final String saleType;

  String _stockLabel() {
    final stock = product.stock?.toInt() ?? 0;
    if (saleType != 'secondary') {
      return 'Warehouse Stock: $stock';
    }
    return 'Van Stock: $stock   |   DB Stock: ${product.distributorStock?.toInt() ?? 0}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isSelected = lineEntry?.isSelected ?? false;
    final int orderQty = lineEntry?.quantity ?? 0;
    final int damagedQty = lineEntry?.damagedQty ?? 0;
    final int qualityQty = lineEntry?.qualityQty ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.borderSoft,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tappable Header: Product Name, Category & Cart Selection Button
          InkWell(
            onTap: onToggleSelect,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _stockLabel(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (product.categoryName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Category: ${product.categoryName}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Cart / Checkbox selection button
                  GestureDetector(
                    onTap: onToggleSelect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.borderSoft,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.check : Icons.add_shopping_cart,
                            size: 16,
                            color: isSelected ? Colors.white : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSelected ? 'Selected (${lineEntry!.totalQty})' : 'Select',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.borderSoft),

          // Quantity Inputs Area
          Padding(
            padding: const EdgeInsets.all(14),
            child: saleType == 'secondary'
                ? Row(
                    children: [
                      Expanded(
                        child: _QtyStepper(
                          label: 'Order Qty',
                          value: orderQty,
                          accentColor: AppColors.primary,
                          onChanged: (val) => onQuantityChanged(val, damagedQty, qualityQty),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QtyStepper(
                          label: 'Damaged Expired',
                          value: damagedQty,
                          accentColor: Colors.orange.shade800,
                          onChanged: (val) => onQuantityChanged(orderQty, val, qualityQty),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QtyStepper(
                          label: 'Damage Quality',
                          value: qualityQty,
                          accentColor: Colors.red.shade700,
                          onChanged: (val) => onQuantityChanged(orderQty, damagedQty, val),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _QtyStepper(
                          label: 'Order Qty',
                          value: orderQty,
                          accentColor: AppColors.primary,
                          onChanged: (val) => onQuantityChanged(val, 0, 0),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatefulWidget {
  final String label;
  final int value;
  final Color accentColor;
  final ValueChanged<int> onChanged;

  const _QtyStepper({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<_QtyStepper> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value > 0 ? widget.value.toString() : '');
  }

  @override
  void didUpdateWidget(covariant _QtyStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final text = widget.value > 0 ? widget.value.toString() : '';
      if (_controller.text != text) {
        _controller.text = text;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: widget.value > 0
                ? widget.accentColor.withOpacity(0.06)
                : AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.value > 0 ? widget.accentColor : AppColors.borderSoft,
              width: widget.value > 0 ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: widget.value > 0 ? () => widget.onChanged(widget.value - 1) : null,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: Container(
                  width: 28,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.remove,
                    size: 14,
                    color: widget.value > 0 ? widget.accentColor : AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.value > 0 ? widget.accentColor : AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val.trim());
                    widget.onChanged(parsed ?? 0);
                  },
                ),
              ),
              InkWell(
                onTap: () => widget.onChanged(widget.value + 1),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: Container(
                  width: 28,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add,
                    size: 14,
                    color: widget.accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
