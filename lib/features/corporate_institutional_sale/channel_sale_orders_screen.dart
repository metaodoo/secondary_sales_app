import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/models/sales/primary_order.dart';
import 'package:secondary_sales/features/corporate_institutional_sale/corporate_institutional_sale_api.dart';

class ChannelSaleOrdersScreen extends StatefulWidget {
  const ChannelSaleOrdersScreen({
    super.key,
    required this.corporate,
  });

  final bool corporate;

  @override
  State<ChannelSaleOrdersScreen> createState() => _ChannelSaleOrdersScreenState();
}

class _ChannelSaleOrdersScreenState extends State<ChannelSaleOrdersScreen> {
  final CorporateInstitutionalSaleApi _api = CorporateInstitutionalSaleApi();
  late Future<List<PrimaryOrder>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = _api.fetchOrders(corporate: widget.corporate);
  }

  Future<void> _reload() async {
    setState(() {
      _orders = _api.fetchOrders(corporate: widget.corporate);
    });
    await _orders;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.corporate ? 'Corporate Sales (CS)' : 'Institution Sales (IS)';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryStrong,
      ),
      body: FutureBuilder<List<PrimaryOrder>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          final orders = snapshot.data ?? const <PrimaryOrder>[];
          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No orders for this business type yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  child: ListTile(
                    title: Text(order.name),
                    subtitle: Text('${order.hubName}\n${order.date}'),
                    isThreeLine: true,
                    trailing: Text(order.amount.toStringAsFixed(2)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
