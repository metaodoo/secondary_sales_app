import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_stock_audit.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';

class MtSecOrderDetailScreen extends StatefulWidget {
  final int orderId;

  const MtSecOrderDetailScreen({super.key, required this.orderId});

  @override
  State<MtSecOrderDetailScreen> createState() => _MtSecOrderDetailScreenState();
}

class _MtSecOrderDetailScreenState extends State<MtSecOrderDetailScreen> {
  MtSecSaleOrder? _order;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final order = await context
        .read<ModernTradeProvider>()
        .fetchMtSecondarySaleDetail(widget.orderId);

    if (!mounted) return;
    setState(() {
      _order = order;
      _isLoading = false;
      if (order == null) {
        _error = context.read<ModernTradeProvider>().error ?? 'Order not found';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _order?.name ?? 'Secondary Sales Order',
          style: const TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadDetail,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _order == null
                  ? const Center(child: Text('No order found'))
                  : RefreshIndicator(
                      onRefresh: _loadDetail,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildHeaderCard(_order!),
                          const SizedBox(height: 16),
                          _buildLinesHeader(_order!),
                          const SizedBox(height: 8),
                          ..._order!.lines.map(_buildLineCard),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildHeaderCard(MtSecSaleOrder order) {
    final dateFormatted = order.date != null
        ? DateFormat('EEE, dd MMM yyyy').format(order.date!.toLocal())
        : 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  order.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.state.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Outlet:',
            '${order.outletName ?? "N/A"} (${order.outletCode ?? ""})',
          ),
          const SizedBox(height: 6),
          _buildInfoRow('Calculation Date:', dateFormatted),
          if (order.employeeName != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow('Merchandiser:', order.employeeName!),
          ],
          if (order.visitName != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow('Visit Reference:', order.visitName!),
          ],
          const SizedBox(height: 6),
          _buildInfoRow('Total Items:', '${order.totalLines} products'),
          const SizedBox(height: 6),
          _buildInfoRow(
            'Total Sold Qty:',
            order.totalSoldQty.toStringAsFixed(1),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinesHeader(MtSecSaleOrder order) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Product Off-Take (${order.lines.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          'Total Sold: ${order.totalSoldQty.toStringAsFixed(1)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryStrong,
          ),
        ),
      ],
    );
  }

  Widget _buildLineCard(MtSecSaleOrderLine line) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Sold: ${line.soldQty.toStringAsFixed(1)} ${line.uomName ?? ""}',
                  style: const TextStyle(
                    color: AppColors.primaryStrong,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (line.lotName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.qr_code,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Lot: ${line.lotName}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (line.expirationDate != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(Exp: ${DateFormat("yyyy-MM-dd").format(line.expirationDate!)})',
                    style: const TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCountColumn(
                  'Opening',
                  line.openingStockQty.toStringAsFixed(1),
                ),
                const Text(
                  '+',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                _buildCountColumn(
                  'Stock In',
                  line.stockInQty.toStringAsFixed(1),
                ),
                const Text(
                  '-',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                _buildCountColumn(
                  'Closing',
                  line.closingStockQty.toStringAsFixed(1),
                ),
                const Text(
                  '=',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                _buildCountColumn(
                  'Sold',
                  line.soldQty.toStringAsFixed(1),
                  isHighlight: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountColumn(String label, String count,
      {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          count,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color:
                isHighlight ? AppColors.primaryStrong : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
