import 'dart:async';
import 'package:secondary_sales/core/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/features/returns/return_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class ReturnProductSelectionScreen extends StatefulWidget {
  const ReturnProductSelectionScreen({
    super.key,
    required this.distributorId,
    required this.initialLines,
  });

  final int distributorId;
  final List<VirtualTransferLineEntry> initialLines;

  @override
  State<ReturnProductSelectionScreen> createState() =>
      _ReturnProductSelectionScreenState();
}

class _ReturnProductSelectionScreenState
    extends State<ReturnProductSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Map<int, VirtualTransferLineEntry> _selectedLines = {};
  Timer? _searchDebounce;
  List<TransferProduct> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedLines.addEntries(
      widget.initialLines.map((line) => MapEntry(line.product.id, line)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    final results = await context.read<ReturnProvider>().fetchReturnProducts(
      distributorId: widget.distributorId,
      search: _searchController.text,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _products = results.map((e) => TransferProduct.fromMap(e)).toList();
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _fetchProducts);
  }

  void _toggleProduct(TransferProduct product) {
    if (product.availableQty <= 0) return;
    setState(() {
      if (_selectedLines.containsKey(product.id)) {
        _selectedLines.remove(product.id);
      } else {
        _selectedLines[product.id] = VirtualTransferLineEntry(
          product: product,
          quantity: 1,
        );
      }
    });
  }

  void _changeQuantity(TransferProduct product, double delta) {
    final line = _selectedLines[product.id];
    if (line == null) return;
    setState(() {
      final next = line.quantity + delta;
      if (next < 1) {
        line.quantity = 1;
      } else if (next > product.availableQty) {
        line.quantity = product.availableQty;
      } else {
        line.quantity = next;
      }
    });
  }

  void _finish() {
    if (_selectedLines.isEmpty) return;
    Navigator.pop(context, _selectedLines.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: const Color(0xFF0038A8),
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Return Products',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          '${_selectedLines.length} selected',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: _selectedLines.isEmpty ? null : _finish,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: ssInputDecoration(
                      'Search products...',
                      Icons.search,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading && _products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_products.isEmpty)
                    const EmptyPanel(message: 'No available products found')
                  else
                    ..._products.map((product) {
                      final line = _selectedLines[product.id];
                      return _ReturnProductCard(
                        product: product,
                        quantity: line?.quantity ?? 1,
                        isSelected: line != null,
                        onTap: () => _toggleProduct(product),
                        onDecrease: () => _changeQuantity(product, -1),
                        onIncrease: () => _changeQuantity(product, 1),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReturnProductCard extends StatelessWidget {
  const _ReturnProductCard({
    required this.product,
    required this.quantity,
    required this.isSelected,
    required this.onTap,
    required this.onDecrease,
    required this.onIncrease,
  });

  final TransferProduct product;
  final double quantity;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFDDE6F2),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (product.requiresLots)
                  const Icon(Icons.qr_code_2, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${product.code ?? 'No code'} • ${product.uomName}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Available: ${product.availableQty.toStringAsFixed(0)} ${product.uomName}',
              style: const TextStyle(color: Color(0xFF16A34A)),
            ),
            if (isSelected) ...[
              const SizedBox(height: 12),
              SmallStepper(
                value: quantity.toStringAsFixed(0),
                onMinus: onDecrease,
                onPlus: onIncrease,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
