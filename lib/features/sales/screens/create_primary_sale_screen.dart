import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/data/models/sales/order_line_entry.dart';
import 'package:secondary_sales/data/models/sales/product.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/sales/screens/product_selection_screen.dart';
import 'package:secondary_sales/core/widgets/order_form_widgets.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class CreatePrimarySaleScreen extends StatefulWidget {
  const CreatePrimarySaleScreen({
    super.key,
    required this.hub,
    this.editOrderId,
    this.initialLines,
  });

  final DistributionHub hub;
  final int? editOrderId;
  final List<OrderLineEntry>? initialLines;

  @override
  State<CreatePrimarySaleScreen> createState() =>
      _CreatePrimarySaleScreenState();
}

class _CreatePrimarySaleScreenState extends State<CreatePrimarySaleScreen> {
  late DistributionHub _hub;
  final List<OrderLineEntry> _lines = [];
  bool _isInitLoaded = false;

  @override
  void initState() {
    super.initState();
    _hub = widget.hub;
    if (widget.initialLines != null && widget.initialLines!.isNotEmpty) {
      _lines.addAll(widget.initialLines!);
    }
    if (widget.editOrderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOrderDetails();
      });
    }
  }

  Future<void> _loadOrderDetails() async {
    final provider = context.read<PrimarySaleProvider>();
    await provider.fetchOrderDetail(widget.editOrderId!);
    final detail = provider.selectedOrder;
    if (detail != null && mounted) {
      setState(() {
        // Resolve distributor details
        if (detail.distributor != null) {
          _hub = DistributionHub(
            id: detail.distributor!.id,
            name: detail.distributor!.name,
            address: detail.distributor!.address,
            phone: detail.distributor!.phone,
          );
        }

        // Pre-populate product lines
        _lines.clear();
        for (final line in detail.lines) {
          if (line.product != null) {
            _lines.add(
              OrderLineEntry(
                product: Product(
                  id: line.product!.id,
                  name: line.product!.name,
                  code: line.product!.defaultCode,
                  price: line.priceUnit,
                  uom: line.uomName,
                  stock: line.product!.qtyAvailable ?? (line.orderedQty + line.balanceQty),
                ),
                quantity: line.orderedQty.toInt(),
                discountPercent: line.discount,
              ),
            );
          }
        }
        _isInitLoaded = true;
      });
    }
  }

  double get _subtotal {
    return _lines.fold(0, (sum, line) => sum + line.grossAmount);
  }

  double get _discount {
    return _lines.fold(0, (sum, line) => sum + line.discountAmount);
  }

  double get _total => _subtotal - _discount;

  Future<void> _openProductPicker() async {
    final provider = context.read<PrimarySaleProvider>();
    if (provider.products.isEmpty) {
      await provider.searchProducts('', partnerId: _hub.id);
    }
    if (!mounted) return;

    final selected = await Navigator.push<List<OrderLineEntry>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductSelectionScreen(
          partnerId: _hub.id,
        ),
      ),
    );
    if (selected == null || selected.isEmpty) return;

    setState(() {
      for (final selectedLine in selected) {
        final existingIndex = _lines.indexWhere(
          (line) => line.product.id == selectedLine.product.id,
        );
        if (existingIndex >= 0) {
          _lines[existingIndex].quantity += selectedLine.quantity;
        } else {
          _lines.add(selectedLine);
        }
      }
    });
  }

  Future<void> _confirmOrder({required bool confirm}) async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product line.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final payloadLines = _lines
        .map(
          (line) => {
            'product': line.product,
            'quantity': line.quantity,
            'discount': line.discountPercent,
          },
        )
        .toList();

    final provider = context.read<PrimarySaleProvider>();
    bool success;
    if (widget.editOrderId != null) {
      success = await provider.editOrder(
        widget.editOrderId!,
        _hub.id,
        payloadLines,
        DateTime.now().add(const Duration(days: 1)),
        confirm: confirm,
      );
    } else {
      success = await provider.submitOrder(
        _hub.id,
        payloadLines,
        DateTime.now().add(const Duration(days: 1)),
        confirm: confirm,
      );
    }

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.editOrderId != null
                ? 'Order updated successfully'
                : 'Order submitted successfully',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    } else {
      final error = provider.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to process order'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrimarySaleProvider>();

    final isLoadingDetails = widget.editOrderId != null && !_isInitLoaded;

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
        title: Text(
          widget.editOrderId != null ? 'Edit Sales Order' : 'New Sales Order',
          style: const TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: ProfileAvatar(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: SafeArea(
        child: isLoadingDetails
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      children: [
                        // Customer Name Field
                        const Text(
                          'Customer Name',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryTint),
                          ),
                          child: Text(
                            _hub.displayNameWithCode,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Customer Address Field
                        const Text(
                          'Customer Address',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primaryTint),
                          ),
                          child: Text(
                            _hub.address ?? 'No address configured in Odoo',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Product Lines Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Product Lines',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: provider.isLoading
                                  ? null
                                  : _openProductPicker,
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              label: const Text(
                                'Add Item',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Product cards list
                        if (_lines.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            alignment: Alignment.center,
                            child: const Text(
                              'No product lines added yet.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                          )
                        else
                          ..._lines.asMap().entries.map((entry) {
                            return OrderLineCard(
                              line: entry.value,
                              onChanged: () => setState(() {}),
                              onRemove: () =>
                                  setState(() => _lines.removeAt(entry.key)),
                            );
                          }),
                      ],
                    ),
                  ),

                  // Bottom Summary & Buttons Panel
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.borderSoft),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x050F172A),
                          blurRadius: 10,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Net Total',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '৳${_total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.primaryStrong,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: provider.isLoading
                                ? null
                                : () => _confirmOrder(confirm: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: provider.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    widget.editOrderId != null
                                        ? 'Save Order'
                                        : 'Submit Order',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
