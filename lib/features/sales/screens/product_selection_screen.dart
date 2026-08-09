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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrimarySaleProvider>().searchProducts(
        '',
        saleType: widget.saleType,
        partnerId: widget.partnerId,
        inStockOnly: _inStockOnly,
        sortBy: _sortBy,
      );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      context.read<PrimarySaleProvider>().searchProducts(
        query,
        saleType: widget.saleType,
        partnerId: widget.partnerId,
        inStockOnly: _inStockOnly,
        sortBy: _sortBy,
      );
    });
  }

  void _finishSelection() {
    if (_selectedLines.isEmpty) return;
    Navigator.pop(context, _selectedLines.values.toList());
  }

  void _toggleProduct(Product product) {
    setState(() {
      if (_selectedLines.containsKey(product.id)) {
        _selectedLines.remove(product.id);
      } else {
        _selectedLines[product.id] = OrderLineEntry(
          product: product,
          quantity: 1,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrimarySaleProvider>();
    final int selectedCount = _selectedLines.values.fold(
      0,
      (sum, line) => sum + line.quantity,
    );
    final bool hasItems = selectedCount > 0;

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
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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

            // Product Count & Sorting Controls Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Product Count Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
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
                      size: 16,
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
                        fontSize: 13,
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
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _inStockOnly = selected;
                      });
                      context.read<PrimarySaleProvider>().searchProducts(
                        _searchController.text,
                        saleType: widget.saleType,
                        partnerId: widget.partnerId,
                        inStockOnly: _inStockOnly,
                        sortBy: _sortBy,
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  // Sort Dropdown Menu
                  PopupMenuButton<String>(
                    initialValue: _sortBy,
                    icon: const Icon(Icons.sort, color: AppColors.textPrimary),
                    tooltip: 'Sort Products',
                    onSelected: (value) {
                      setState(() {
                        _sortBy = value;
                      });
                      context.read<PrimarySaleProvider>().searchProducts(
                        _searchController.text,
                        saleType: widget.saleType,
                        partnerId: widget.partnerId,
                        inStockOnly: _inStockOnly,
                        sortBy: _sortBy,
                      );
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
            const SizedBox(height: 8),

            // Products list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await provider.searchProducts(
                    _searchController.text,
                    saleType: widget.saleType,
                    partnerId: widget.partnerId,
                    inStockOnly: _inStockOnly,
                  );
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
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        itemCount: provider.products.length,
                        itemBuilder: (context, index) {
                          final product = provider.products[index];
                          final isSelected = _selectedLines.containsKey(
                            product.id,
                          );
                          return ProductSelectionCard(
                            product: product,
                            isSelected: isSelected,
                            saleType: widget.saleType,
                            onTap: () => _toggleProduct(product),
                          );
                        },
                      ),
              ),
            ),

            // Bottom Confirm Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderSoft)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: hasItems ? _finishSelection : null,
                  icon: Icon(
                    Icons.shopping_cart_outlined,
                    color: hasItems ? Colors.white : AppColors.textSecondary,
                  ),
                  label: Text(
                    'Add ${_selectedLines.length} Items',
                    style: TextStyle(
                      color: hasItems ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
    required this.isSelected,
    required this.onTap,
    this.saleType = 'primary',
  });

  final Product product;
  final bool isSelected;
  final VoidCallback onTap;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stockLabel(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (product.nearestExpiry != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Nearest Expiry: ${product.nearestExpiry}',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Selection indicator circle
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.white,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.borderSoft,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
