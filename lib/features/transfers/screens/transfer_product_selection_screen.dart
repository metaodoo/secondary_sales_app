import 'dart:async';
import 'package:secondary_sales/core/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/features/transfers/transfer_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class TransferProductSelectionScreen extends StatefulWidget {
  const TransferProductSelectionScreen({
    super.key,
    required this.destinationLocationId,
    required this.initialLines,
  });

  final int destinationLocationId;
  final List<VirtualTransferLineEntry> initialLines;

  @override
  State<TransferProductSelectionScreen> createState() =>
      _TransferProductSelectionScreenState();
}

class _TransferProductSelectionScreenState
    extends State<TransferProductSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Map<int, VirtualTransferLineEntry> _selectedLines = {};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _selectedLines.addEntries(
      widget.initialLines.map((line) => MapEntry(line.product.id, line)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransferProvider>().searchTransferProducts(
        destinationLocationId: widget.destinationLocationId,
      );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      context.read<TransferProvider>().searchTransferProducts(
        destinationLocationId: widget.destinationLocationId,
        search: value,
      );
    });
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

  void _finish() {
    if (_selectedLines.isEmpty) return;
    Navigator.pop(context, _selectedLines.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransferProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: const Color(0xFF2563EB),
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
                          'Select Transfer Products',
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
                  if (provider.error != null) ErrorPanel(provider.error!),
                  if (provider.isLoading && provider.transferProducts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (provider.transferProducts.isEmpty)
                    const EmptyPanel(message: 'No available products found')
                  else
                    ...provider.transferProducts.map((product) {
                      final line = _selectedLines[product.id];
                      return _TransferProductCard(
                        product: product,
                        isSelected: line != null,
                        onTap: () => _toggleProduct(product),
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

class _TransferProductCard extends StatelessWidget {
  const _TransferProductCard({
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  final TransferProduct product;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasStock = product.availableQty > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEFF6FF)
                  : (hasStock ? Colors.white : const Color(0xFFF9FAFB)),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFE5E7EB),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
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
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'SKU: ${product.code ?? 'N/A'}  •  UoM: ${product.uomName}',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFD1D5DB),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StockBadge(
                        label: 'Fresh',
                        qty: product.freshQty,
                        color: const Color(0xFF15803D),
                        backgroundColor: const Color(0xFFF0FDF4),
                        borderColor: const Color(0xFFBBF7D0),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StockBadge(
                        label: 'QC',
                        qty: product.qcQty,
                        color: const Color(0xFFB45309),
                        backgroundColor: const Color(0xFFFFFBEB),
                        borderColor: const Color(0xFFFDE68A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StockBadge(
                        label: 'Damage',
                        qty: product.damageQty,
                        color: const Color(0xFFB91C1C),
                        backgroundColor: const Color(0xFFFEF2F2),
                        borderColor: const Color(0xFFFECACA),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({
    required this.label,
    required this.qty,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final double qty;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final formattedQty =
        qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formattedQty,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
