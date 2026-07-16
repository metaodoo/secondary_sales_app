import 'dart:async';
import 'package:secondary_sales/core/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/sales/order_line_entry.dart';
import 'package:secondary_sales/data/models/sales/product.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class ProductSelectionScreen extends StatefulWidget {
  final String saleType;
  final int? partnerId;
  const ProductSelectionScreen({super.key, this.saleType = 'primary', this.partnerId});

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  final Map<int, OrderLineEntry> _selectedLines = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrimarySaleProvider>().searchProducts('', saleType: widget.saleType, partnerId: widget.partnerId);
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
      context.read<PrimarySaleProvider>().searchProducts(query, saleType: widget.saleType, partnerId: widget.partnerId);
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

  void _changeQuantity(Product product, int delta) {
    setState(() {
      if (!_selectedLines.containsKey(product.id)) {
        if (delta > 0) {
          _selectedLines[product.id] = OrderLineEntry(
            product: product,
            quantity: delta,
          );
        }
        return;
      }
      final line = _selectedLines[product.id]!;
      final next = line.quantity + delta;
      if (next <= 0) {
        _selectedLines.remove(product.id);
      } else {
        line.quantity = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrimarySaleProvider>();
    final selectedCount = _selectedLines.values.fold(
      0,
      (sum, line) => sum + line.quantity,
    );
    final hasItems = _selectedLines.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 28,
          ),
        ),
        title: const Text(
          'Select Products',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.search,
              color: AppColors.textPrimary,
              size: 26,
            ),
          ),
        ],
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

            // Products list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await provider.searchProducts(_searchController.text, saleType: widget.saleType, partnerId: widget.partnerId);
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
                          final selectedLine = _selectedLines[product.id];
                          final qty = selectedLine?.quantity ?? 0;
                          return ProductSelectionCard(
                            product: product,
                            quantity: qty,
                            onTap: () => _toggleProduct(product),
                            onDecrease: () => _changeQuantity(product, -1),
                            onIncrease: () => _changeQuantity(product, 1),
                            onQuantityChanged: (newQty) {
                              setState(() {
                                if (newQty <= 0) {
                                  _selectedLines.remove(product.id);
                                } else {
                                  _selectedLines[product.id] = OrderLineEntry(
                                    product: product,
                                    quantity: newQty,
                                  );
                                }
                              });
                            },
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
                    'Add $selectedCount Items',
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
    required this.quantity,
    required this.onTap,
    required this.onDecrease,
    required this.onIncrease,
    this.onQuantityChanged,
  });

  final Product product;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<int>? onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = quantity > 0;
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
                    'Van Stock: ${product.stock?.toInt() ?? 0}   |   DB Stock: ${product.distributorStock?.toInt() ?? 0}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Minus button
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderSoft),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.remove,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: isSelected ? onDecrease : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 52,
                        height: 38,
                        child: TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: false),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.borderSoft),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.borderSoft),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                          enabled: isSelected,
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 0 && onQuantityChanged != null) {
                              onQuantityChanged!(parsed);
                            }
                          },
                          controller: TextEditingController(
                            text: '$quantity',
                          )..selection = TextSelection.collapsed(offset: '$quantity'.length),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Plus button
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderSoft),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.add,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: onIncrease,
                        ),
                      ),
                    ],
                  ),
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
