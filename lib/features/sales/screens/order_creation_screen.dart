import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/sales/screens/order_detail_screen.dart';
import 'package:secondary_sales/data/models/sales/order_line_entry.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/sales/screens/product_selection_screen.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/widgets/order_form_widgets.dart';

class OrderLineModel {
  final int productId;
  final String productName;
  final double unitPrice;
  final int dbStock;
  final int vanStock;
  int orderQty;
  int damagedExpiredQty;
  int damageQualityQty;
  bool adjustWithBill;

  OrderLineModel({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.dbStock = 0,
    this.vanStock = 0,
    this.orderQty = 0,
    this.damagedExpiredQty = 0,
    this.damageQualityQty = 0,
    this.adjustWithBill = false,
  });

  /// Quantity actually charged for. A bill-adjusted return is settled against
  /// the bill rather than swapped for fresh stock, so the returned units come
  /// off what the customer pays -- and a returns-only line goes negative.
  /// Mirrors `sale.order.line._ss_billable_qty` on the server.
  int get billableQty => adjustWithBill
      ? orderQty - (damagedExpiredQty + damageQualityQty)
      : orderQty;

  double get lineTotal => unitPrice * billableQty;
}

class OrderCreationScreen extends StatefulWidget {
  final int outletId;
  final String customerName;
  final String? outletCode;
  final int? mediumId;
  final int? routeId;
  final int? visitId;
  final int? editOrderId;
  final List<OrderLineEntry>? initialLines;

  const OrderCreationScreen({
    super.key,
    required this.outletId,
    required this.customerName,
    this.outletCode,
    this.mediumId,
    this.routeId,
    this.visitId,
    this.editOrderId,
    this.initialLines,
  });

  @override
  State<OrderCreationScreen> createState() => _OrderCreationScreenState();
}

class _OrderCreationScreenState extends State<OrderCreationScreen> {
  List<OrderLineModel> lines = [];
  bool _isSubmitting = false;
  bool _isInitLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLines != null && widget.initialLines!.isNotEmpty) {
      for (final entry in widget.initialLines!) {
        lines.add(
          OrderLineModel(
            productId: entry.product.id,
            productName: entry.product.name,
            unitPrice: entry.product.price,
            dbStock: entry.product.distributorStock?.toInt() ?? 0,
            vanStock: entry.product.stock?.toInt() ?? 0,
            orderQty: entry.quantity,
            damagedExpiredQty: entry.damagedQty,
            damageQualityQty: entry.qualityQty,
            adjustWithBill: entry.adjustWithBill,
          ),
        );
      }
    }
    if (widget.editOrderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOrderDetails();
      });
    }
  }

  Future<void> _loadOrderDetails() async {
    final provider = context.read<PrimarySaleProvider>();
    await provider.fetchOrderDetail(widget.editOrderId!, saleType: 'secondary');
    final detail = provider.selectedOrder;
    if (detail != null && mounted) {
      setState(() {
        lines.clear();
        for (final line in detail.lines) {
          if (line.product != null) {
            lines.add(
              OrderLineModel(
                productId: line.product!.id,
                productName: line.product!.name,
                unitPrice: line.priceUnit,
                dbStock: line.product!.distributorQtyAvailable?.toInt() ?? 0,
                vanStock:
                    (line.product!.qtyAvailable ??
                            (line.orderedQty + line.balanceQty))
                        .toInt(),
                orderQty: line.orderedQty.toInt(),
                damagedExpiredQty: line.damagedExpiredQty.toInt(),
                damageQualityQty: line.damageQualityQty.toInt(),
              ),
            );
          }
        }
        _isInitLoaded = true;
      });
    }
  }

  String get _currencySymbol {
    final detail = context.read<PrimarySaleProvider>().selectedOrder;
    return detail?.amounts.currencySymbol ?? '৳';
  }

  double get subtotal => lines.fold(0, (sum, line) => sum + line.lineTotal);
  double get netTotal => subtotal; // Apply discounts/taxes here if needed

  void _addDummyProduct() {
    _showProductSelection();
  }

  Future<void> _showProductSelection() async {
    final provider = context.read<PrimarySaleProvider>();
    if (provider.products.isEmpty) {
      await provider.searchProducts(
        '',
        saleType: 'secondary',
        partnerId: widget.outletId,
      );
    }
    if (!mounted) return;

    final selected = await Navigator.push<List<OrderLineEntry>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductSelectionScreen(
          saleType: 'secondary',
          partnerId: widget.outletId,
        ),
      ),
    );
    if (selected == null || selected.isEmpty) return;

    setState(() {
      for (final entry in selected) {
        final existingIndex = lines.indexWhere(
          (l) => l.productId == entry.product.id,
        );
        if (existingIndex >= 0) {
          lines[existingIndex].orderQty += entry.quantity;
          lines[existingIndex].damagedExpiredQty += entry.damagedQty;
          lines[existingIndex].damageQualityQty += entry.qualityQty;
          // Merging into an existing line: if either side needs the bill
          // adjustment, the merged line does.
          lines[existingIndex].adjustWithBill =
              lines[existingIndex].adjustWithBill || entry.adjustWithBill;
        } else {
          lines.add(
            OrderLineModel(
              productId: entry.product.id,
              productName: entry.product.name,
              unitPrice: entry.product.price,
              dbStock: entry.product.distributorStock?.toInt() ?? 0,
              vanStock: entry.product.stock?.toInt() ?? 0,
              orderQty: entry.quantity,
              damagedExpiredQty: entry.damagedQty,
              damageQualityQty: entry.qualityQty,
              adjustWithBill: entry.adjustWithBill,
            ),
          );
        }
      }
    });
  }

  Future<void> _submitOrder() async {
    if (lines.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService.instance;
      apiService.updateAccessToken(auth.accessToken);
      apiService.updateSessionId(auth.sessionId);
      apiService.updateEmployeeId(auth.employeeId);

      final items = lines
          .map(
            (l) => {
              'product_id': l.productId,
              'order_qty': l.orderQty,
              'damaged_expired_qty': l.damagedExpiredQty,
              'damage_quality_qty': l.damageQualityQty,
              'ss_adjust_with_bill': l.adjustWithBill,
              'price_unit': l.unitPrice,
            },
          )
          .toList();

      if (widget.editOrderId != null) {
        await apiService.updateSecondarySaleOrder(
          orderId: widget.editOrderId!,
          outletId: widget.outletId,
          items: items,
          mediumId: widget.mediumId,
          routeId: widget.routeId,
          visitId: widget.visitId,
          confirm: true,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order updated successfully!')),
          );
          Navigator.pop(context);
        }
      } else {
        final result = await apiService.createSecondarySaleOrder(
          outletId: widget.outletId,
          items: items,
          mediumId: widget.mediumId,
          routeId: widget.routeId,
          visitId: widget.visitId,
          confirm: true,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order submitted successfully!')),
          );
          final orderId = result['id'] as int?;
          if (orderId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(
                  orderId: orderId,
                  fallbackName: result['name']?.toString() ?? 'Order',
                  saleType: 'secondary',
                ),
              ),
            );
          } else {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoadingDetails = widget.editOrderId != null && !_isInitLoaded;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          widget.editOrderId != null
              ? 'Edit Secondary Sales'
              : 'Secondary Sales',
        ),
        centerTitle: true,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: ProfileAvatar(),
          ),
        ],
      ),
      body: SafeArea(
        child: isLoadingDetails
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Header Card
                          const Text(
                            'Ordering For',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDF0FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD6DDFB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryStrong,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.storefront,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.customerName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (widget.outletCode != null &&
                                          widget.outletCode!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Code: ${widget.outletCode!.trim()}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'Client ID: #${widget.outletId} • Selected Outlet',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Added Products Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Added Products',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              TextButton.icon(
                                onPressed:
                                    _addDummyProduct, // TODO: Open Product Selection Screen
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 18,
                                ),
                                label: const Text('Add Items'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryStrong,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Product Lines
                          if (lines.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: Text(
                                  'No products added yet.\nClick "Add Items" to begin.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...lines.map((line) => _buildProductCard(line)),

                          const SizedBox(height: 12),

                          // Total Summary Card
                          if (lines.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF0FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD6DDFB),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Subtotal',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '$_currencySymbol${subtotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(
                                      color: Color(0xFFD6DDFB),
                                      height: 1,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Net Total',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '$_currencySymbol${netTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryStrong,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Confirm Button
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (lines.isNotEmpty && !_isSubmitting)
                          ? _submitOrder
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryStrong,
                        disabledBackgroundColor: AppColors.borderSoft,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.editOrderId != null ? 'Save' : 'Confirm',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProductCard(OrderLineModel line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
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
                      line.productName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unit Price: $_currencySymbol${line.unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    lines.remove(line);
                  });
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stock Badges
          Row(
            children: [
              _buildBadge('DB: ${line.dbStock}'),
              const SizedBox(width: 8),
              _buildBadge('Van: ${line.vanStock}'),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.borderSoft, height: 1),
          ),

          // Qty Controls
          Row(
            children: [
              Expanded(
                child: _buildQtyControl(
                  label: 'Order Qty',
                  value: line.orderQty,
                  onChanged: (val) {
                    setState(() {
                      line.orderQty = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQtyControl(
                  label: 'Damaged Expire Qty',
                  value: line.damagedExpiredQty,
                  onChanged: (val) {
                    setState(() {
                      line.damagedExpiredQty = val;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQtyControl(
                  label: 'Damage Quality Qty',
                  value: line.damageQualityQty,
                  onChanged: (val) {
                    setState(() {
                      line.damageQualityQty = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ),

          // Mirrors the toggle in product selection so the rep can see and
          // change the decision at review time, not only while picking.
          if (line.damagedExpiredQty > 0 || line.damageQualityQty > 0) ...[
            const SizedBox(height: 8),
            AdjustReturnToggle(
              value: line.adjustWithBill,
              vanStock: line.vanStock,
              onChanged: (val) =>
                  setState(() => line.adjustWithBill = val),
            ),
          ],

          const SizedBox(height: 16),

          // Line Total
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Line Total',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '$_currencySymbol${line.lineTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryStrong,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF0FF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildQtyControl({
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        SmallStepper(
          value: '$value',
          isDecimal: false,
          onMinus: () {
            if (value > 0) onChanged(value - 1);
          },
          onPlus: () => onChanged(value + 1),
          onValueInput: (val) {
            final parsed = int.tryParse(val);
            if (parsed != null && parsed >= 0) {
              onChanged(parsed);
            }
          },
        ),
      ],
    );
  }
}
