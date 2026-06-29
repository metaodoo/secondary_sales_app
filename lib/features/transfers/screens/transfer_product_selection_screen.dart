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

class _TransferProductCard extends StatelessWidget {
  const _TransferProductCard({
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
