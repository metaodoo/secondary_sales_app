import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/features/transfers/transfer_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/access/permission_gate.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/features/van_loading/screens/van_load_form_screen.dart';

class VirtualTransferDetailScreen extends StatefulWidget {
  const VirtualTransferDetailScreen({super.key, required this.initialTransfer});

  final VirtualTransfer initialTransfer;

  @override
  State<VirtualTransferDetailScreen> createState() =>
      _VirtualTransferDetailScreenState();
}

class _VirtualTransferDetailScreenState
    extends State<VirtualTransferDetailScreen> {
  late Future<VirtualTransfer> _transferFuture;

  @override
  void initState() {
    super.initState();
    _transferFuture = context.read<TransferProvider>().getVirtualTransfer(
      widget.initialTransfer.id,
    );
  }

  Future<void> _refresh() async {
    final future = context.read<TransferProvider>().getVirtualTransfer(
      widget.initialTransfer.id,
    );
    setState(() => _transferFuture = future);
    await future;
  }

  Future<void> _validate(VirtualTransfer transfer) async {
    final updated = await context
        .read<TransferProvider>()
        .validateVirtualTransfer(transfer.id);
    if (!mounted) return;
    if (updated == null) {
      _showError();
      return;
    }
    setState(() => _transferFuture = Future.value(updated));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transfer validated successfully'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _cancel(VirtualTransfer transfer) async {
    final updated = await context
        .read<TransferProvider>()
        .cancelVirtualTransfer(transfer.id);
    if (!mounted) return;
    if (updated == null) {
      _showError();
      return;
    }
    setState(() => _transferFuture = Future.value(updated));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transfer cancelled')));
  }

  void _showError() {
    final error = context.read<TransferProvider>().error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Action failed'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _editTransfer(VirtualTransfer transfer) async {
    final updated = await Navigator.push<VirtualTransfer>(
      context,
      MaterialPageRoute(
        builder: (_) => VanLoadFormScreen(
          isLoad: transfer.vanOperationType != 'unload',
          existingTransfer: transfer,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _transferFuture = Future.value(updated);
      });
    }
  }

  String _nameOf(Map<String, dynamic>? value) {
    final name = value?['name'];
    return name == null || name.toString().trim().isEmpty
        ? '-'
        : name.toString();
  }

  String _stateLabel(String state) {
    return switch (state) {
      'done' => 'DONE',
      'cancel' => 'CANCELLED',
      'assigned' => 'READY',
      'confirmed' => 'CONFIRMED',
      'draft' => 'DRAFT',
      _ => state.toUpperCase(),
    };
  }

  Color _stateColor(String state) {
    return switch (state) {
      'done' => const Color(0xFF10B981),
      'cancel' => Colors.red,
      'assigned' => const Color(0xFF2563EB),
      'confirmed' => const Color(0xFFF59E0B),
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransferProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            FutureBuilder<VirtualTransfer>(
              future: _transferFuture,
              builder: (context, snapshot) {
                final transfer = snapshot.data ?? widget.initialTransfer;
                final bool isLoad = transfer.vanOperationType?.toLowerCase() == 'load';
                final bool isScrap = transfer.ssTransferCategory?.toLowerCase() == 'scrap';
                final String subtitle = isLoad
                    ? 'Van Load'
                    : (isScrap ? 'Van Scrap Unload' : 'Van Unload');

                return BlueHeader(
                  title: transfer.name,
                  subtitle: subtitle,
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  trailing: ![
                    'done',
                    'cancel',
                  ].contains(transfer.state.toLowerCase())
                      ? IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () => _editTransfer(transfer),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
            Expanded(
              child: FutureBuilder<VirtualTransfer>(
                future: _transferFuture,
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
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    );
                  }

                  final transfer = snapshot.data ?? widget.initialTransfer;

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: ssPanelDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Status',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _stateColor(
                                        transfer.state,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _stateLabel(transfer.state),
                                      style: TextStyle(
                                        color: _stateColor(transfer.state),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _DetailRow(
                                label: 'Distributor',
                                value: _nameOf(transfer.distributor),
                              ),
                              _DetailRow(
                                label: 'Source',
                                value: _nameOf(transfer.sourceLocation),
                              ),
                              _DetailRow(
                                label: 'Destination',
                                value: _nameOf(transfer.destinationLocation),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Products',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...transfer.lines.map((line) => _MoveLineCard(line)),
                      ],
                    ),
                  );
                },
              ),
            ),
            FutureBuilder<VirtualTransfer>(
              future: _transferFuture,
              builder: (context, snapshot) {
                final transfer = snapshot.data ?? widget.initialTransfer;
                if (!transfer.canValidate && !transfer.canCancel) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      if (transfer.canValidate)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: provider.isLoading
                                ? null
                                : () => _validate(transfer),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Validate Transfer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      if (transfer.canValidate && transfer.canCancel)
                        const SizedBox(height: 10),
                      if (transfer.canCancel)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: PermissionGate(
                            resourceKey: AppAction.transferCancel,
                            child: TextButton(
                              onPressed: provider.isLoading
                                  ? null
                                  : () => _cancel(transfer),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Cancel Transfer',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 98,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveLineCard extends StatelessWidget {
  const _MoveLineCard(this.line);

  final VirtualTransferLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.productName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Demand',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${line.demandQty.toStringAsFixed(0)} ${line.uomName}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'Reserved',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${line.quantity.toStringAsFixed(0)} ${line.uomName}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (line.requiresLots && line.lotLines.isNotEmpty) ...[
            const Divider(height: 22),
            ...line.lotLines.map((lotLine) {
              final lot = lotLine['lot'];
              final lotName = lot is Map ? lot['name'] : null;
              final quantity = lotLine['quantity'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lotName?.toString() ?? 'Lot',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    Text(
                      '${quantity ?? 0} ${line.uomName}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
