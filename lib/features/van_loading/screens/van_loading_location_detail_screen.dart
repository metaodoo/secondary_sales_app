import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/inventory/virtual_location.dart';
import 'package:secondary_sales/features/transfers/transfer_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class VanLoadingLocationDetailScreen extends StatefulWidget {
  const VanLoadingLocationDetailScreen({
    super.key,
    required this.initialLocation,
  });

  final VirtualLocation initialLocation;

  @override
  State<VanLoadingLocationDetailScreen> createState() =>
      _VanLoadingLocationDetailScreenState();
}

class _VanLoadingLocationDetailScreenState
    extends State<VanLoadingLocationDetailScreen> {
  late Future<VirtualLocation> _locationFuture;

  @override
  void initState() {
    super.initState();
    _locationFuture = context.read<TransferProvider>().getVirtualLocation(
      widget.initialLocation.id,
    );
  }

  Future<void> _refresh() async {
    final future = context.read<TransferProvider>().getVirtualLocation(
      widget.initialLocation.id,
    );
    setState(() => _locationFuture = future);
    await future;
  }

  String _nameOf(Map<String, dynamic>? value) {
    final name = value?['name'];
    return name == null || name.toString().trim().isEmpty
        ? '-'
        : name.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: widget.initialLocation.name,
              subtitle: 'Van loading location',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              trailing: IconButton(
                onPressed: () => setState(() {
                  _locationFuture = context
                      .read<TransferProvider>()
                      .getVirtualLocation(widget.initialLocation.id);
                }),
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ),
            Expanded(
              child: FutureBuilder<VirtualLocation>(
                future: _locationFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ErrorPanel(snapshot.error.toString()),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {
                            _locationFuture = context
                                .read<TransferProvider>()
                                .getVirtualLocation(widget.initialLocation.id);
                          }),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    );
                  }

                  final location = snapshot.data ?? widget.initialLocation;

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 560,
                                ),
                                child: Column(
                                  children: [
                                    _SummaryCard(location: location),
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: ssPanelDecoration(),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Assignment',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          _DetailRow(
                                            label: 'Employee',
                                            value: _nameOf(location.employee),
                                          ),
                                          _DetailRow(
                                            label: 'Distributor',
                                            value: _nameOf(
                                              location.distributor,
                                            ),
                                          ),
                                          _DetailRow(
                                            label: 'Business Type',
                                            value: 'Van Loading Location',
                                          ),
                                          _DetailRow(
                                            label: 'Odoo Usage',
                                            value: location.usage.isEmpty
                                                ? '-'
                                                : location.usage,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.location});

  final VirtualLocation location;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ssPanelDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Van Loading Location',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
