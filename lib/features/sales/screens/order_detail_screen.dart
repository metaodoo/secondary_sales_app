import 'dart:convert';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/sales/sale_order_detail.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/sales/screens/validate_delivery_screen.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.fallbackName,
    this.saleType = 'primary',
  });

  final int orderId;
  final String fallbackName;
  final String saleType;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrimarySaleProvider>().fetchOrderDetail(widget.orderId, saleType: widget.saleType);
    });
  }

  Future<void> _printOrder() async {
    final provider = context.read<PrimarySaleProvider>();
    final result = await provider.printOrder(widget.orderId, saleType: widget.saleType);
    if (!mounted) return;

    if (result == null) {
      final error = provider.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not print order.')),
      );
      return;
    }

    final String? fileContent = result['file_content'];
    final String filename = result['filename'] ?? 'order_${widget.orderId}.pdf';

    if (fileContent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No PDF content returned from server.')),
      );
      return;
    }

    try {
      final bytes = base64Decode(fileContent);
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to process PDF: $e')));
    }
  }

  Future<void> _openDeliveryValidation(
    SaleOrderDetail order,
    DeliveryOrderSummary picking,
  ) async {
    final updated = await Navigator.of(context).push<SaleOrderDetail>(
      MaterialPageRoute(
        builder: (_) => ValidateDeliveryScreen(
          orderId: order.id,
          orderName: order.name,
          pickingId: picking.id,
          pickingName: picking.name,
          pickingState: picking.state,
          saleType: widget.saleType,
        ),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      context.read<PrimarySaleProvider>().fetchOrderDetail(widget.orderId, saleType: widget.saleType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrimarySaleProvider>();
    final order = provider.selectedOrder?.id == widget.orderId
        ? provider.selectedOrder
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: order?.name ?? widget.fallbackName,
              subtitle: order?.distributor?.name ?? 'Sale Order',
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => context
                    .read<PrimarySaleProvider>()
                    .fetchOrderDetail(widget.orderId, saleType: widget.saleType),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (provider.error != null) ErrorPanel(provider.error!),
                    if (provider.isLoading && order == null)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (order == null)
                      const EmptyPanel(message: 'Order not found')
                    else ...[
                      _OrderStatusPanel(order: order),
                      const SizedBox(height: 16),
                      _OrderLinesPanel(order: order),
                      const SizedBox(height: 16),
                      _OrderTotalsPanel(order: order),
                      const SizedBox(height: 16),
                      _DeliveriesPanel(
                        order: order,
                        onTapDelivery: (picking) =>
                            _openDeliveryValidation(order, picking),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _printOrder,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text(
                            'Print Order',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatusPanel extends StatelessWidget {
  const _OrderStatusPanel({required this.order});

  final SaleOrderDetail order;

  @override
  Widget build(BuildContext context) {
    Color delivBgColor;
    Color delivTextColor;
    String delivText;

    switch (order.deliveryStatus.toLowerCase()) {
      case 'full':
        delivBgColor = const Color(0xFFDCFCE7);
        delivTextColor = const Color(0xFF16A34A);
        delivText = 'DELIVERED';
        break;
      case 'partial':
        delivBgColor = const Color(0xFFFEF3C7);
        delivTextColor = const Color(0xFFD97706);
        delivText = 'PARTIAL';
        break;
      case 'no':
      default:
        delivBgColor = AppColors.borderMuted;
        delivTextColor = AppColors.textSecondary;
        delivText = 'PENDING';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7EEFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.state.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: delivBgColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  delivText,
                  style: TextStyle(
                    color: delivTextColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Created: ${_formatServerDate(order.dateOrder)}'),
          const SizedBox(height: 8),
          Text(
            'Expected Delivery: ${_formatServerDate(order.expectedDeliveryDate ?? '')}',
          ),
        ],
      ),
    );
  }
}

class _OrderLinesPanel extends StatelessWidget {
  const _OrderLinesPanel({required this.order});

  final SaleOrderDetail order;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF4FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Text(
              'Product Lines',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          ...order.lines.map(
            (line) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.product?.name ?? 'Product',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        _money(order, line.priceTotal),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_money(order, line.priceUnit)}/${line.uomName ?? ''}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _QtyTile(
                          label: 'Ordered',
                          value: formatQty(line.orderedQty),
                          color: AppColors.primarySoft,
                          valueColor: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QtyTile(
                          label: 'Delivered',
                          value: formatQty(line.deliveredQty),
                          color: const Color(0xFFECFDF3),
                          valueColor: const Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QtyTile(
                          label: 'Balance',
                          value: formatQty(line.balanceQty),
                          color: const Color(0xFFFFF7ED),
                          valueColor: const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyTile extends StatelessWidget {
  const _QtyTile({
    required this.label,
    required this.value,
    required this.color,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _OrderTotalsPanel extends StatelessWidget {
  const _OrderTotalsPanel({required this.order});

  final SaleOrderDetail order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ssPanelDecoration(),
      child: Column(
        children: [
          _AmountRow(
            label: 'Subtotal',
            value: _money(order, order.amounts.untaxed),
          ),
          const Divider(),
          _AmountRow(
            label: 'Total',
            value: _money(order, order.amounts.total),
            isStrong: true,
            valueColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isStrong = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final weight = isStrong ? FontWeight.w900 : FontWeight.w500;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: weight)),
          ),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: weight),
          ),
        ],
      ),
    );
  }
}

String _money(SaleOrderDetail order, double value) {
  return '${order.amounts.currencySymbol ?? '৳'}${value.toStringAsFixed(2)}';
}

String _formatServerDate(String value) {
  if (value.isEmpty) return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.split('.').first;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${parsed.day.toString().padLeft(2, '0')} '
      '${months[parsed.month - 1]} ${parsed.year}';
}

class _DeliveriesPanel extends StatelessWidget {
  const _DeliveriesPanel({required this.order, required this.onTapDelivery});

  final SaleOrderDetail order;
  final ValueChanged<DeliveryOrderSummary> onTapDelivery;

  @override
  Widget build(BuildContext context) {
    if (order.deliveryOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF4FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Text(
                  'Delivery List',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${order.deliveryOrders.length} ${order.deliveryOrders.length == 1 ? 'Record' : 'Records'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Delivery Items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: order.deliveryOrders.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final picking = order.deliveryOrders[index];
              return InkWell(
                onTap: () => onTapDelivery(picking),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            picking.name,
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatServerDate(picking.scheduledDate ?? ''),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      _buildStatusPill(picking.state, picking.stateLabel),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String state, String? label) {
    Color bg;
    String text = label ?? state;

    switch (state.toLowerCase()) {
      case 'done':
        bg = const Color(0xFF10B981); // Emerald Green
        text = 'Delivered';
        break;
      case 'assigned':
        bg = const Color(0xFFF59E0B); // Amber / Orange (Shipped/Ready)
        text = 'Ready';
        break;
      case 'confirmed':
        bg = const Color(0xFF3B82F6); // Blue
        text = 'Waiting Availability';
        break;
      case 'waiting':
        bg = const Color(0xFF9CA3AF); // Gray
        text = 'Waiting';
        break;
      case 'cancel':
        bg = const Color(0xFFEF4444); // Red
        text = 'Cancelled';
        break;
      default:
        bg = const Color(0xFF6B7280); // Light Gray
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
