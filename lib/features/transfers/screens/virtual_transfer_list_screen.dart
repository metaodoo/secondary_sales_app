import 'dart:async';
import 'package:secondary_sales/core/util/parse.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/features/transfers/transfer_provider.dart';
import 'package:secondary_sales/features/transfers/screens/create_virtual_transfer_screen.dart';
import 'package:secondary_sales/features/transfers/screens/virtual_transfer_detail_screen.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/access/permission_gate.dart';
import 'package:secondary_sales/core/access/access_resources.dart';

class VirtualTransferListScreen extends StatefulWidget {
  const VirtualTransferListScreen({super.key});

  @override
  State<VirtualTransferListScreen> createState() =>
      _VirtualTransferListScreenState();
}

class _VirtualTransferListScreenState extends State<VirtualTransferListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _state = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchTransfers());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTransfers() {
    return context.read<TransferProvider>().fetchVirtualTransfers(
      search: _searchController.text,
      state: _state,
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _fetchTransfers);
  }

  Future<void> _openCreateTransfer() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateVirtualTransferScreen()),
    );
    if (mounted) {
      _fetchTransfers();
    }
  }

  Future<void> _openTransferDetail(VirtualTransfer transfer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VirtualTransferDetailScreen(initialTransfer: transfer),
      ),
    );
    if (mounted) {
      _fetchTransfers();
    }
  }

  String _nameOf(Map<String, dynamic>? value) {
    return formatLocationName(value);
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
      'draft' => AppColors.textSecondary,
      _ => AppColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransferProvider>();
    final transfers = provider.virtualTransfers;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: PermissionGate(
        resourceKey: AppAction.transferCreate,
        child: SsCreateFab(
          label: 'New Virtual Transfer',
          onPressed: provider.isLoading ? null : _openCreateTransfer,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: 'Virtual Transfers',
              subtitle: 'Distributor stock to van loading',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              trailing: PermissionGate(
                resourceKey: AppAction.transferCreate,
                child: IconButton(
                  onPressed: _openCreateTransfer,
                  icon: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchTransfers,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, kSsFabScrollPadding),
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: ssInputDecoration(
                        'Search transfers...',
                        Icons.search,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _state,
                      decoration: ssInputDecoration('', Icons.filter_list),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Status'),
                        ),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(
                          value: 'confirmed',
                          child: Text('Confirmed'),
                        ),
                        DropdownMenuItem(
                          value: 'assigned',
                          child: Text('Ready'),
                        ),
                        DropdownMenuItem(value: 'done', child: Text('Done')),
                        DropdownMenuItem(
                          value: 'cancel',
                          child: Text('Cancelled'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _state = value);
                        _fetchTransfers();
                      },
                    ),
                    const SizedBox(height: 16),
                    if (provider.error != null) ErrorPanel(provider.error!),
                    if (provider.isLoading && transfers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (transfers.isEmpty)
                      const EmptyPanel(message: 'No virtual transfers found')
                    else ...[
                      if (provider.isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        ),
                      ...transfers.map(
                        (transfer) => _TransferCard(
                          transfer: transfer,
                          stateLabel: _stateLabel(transfer.state),
                          stateColor: _stateColor(transfer.state),
                          distributor: _nameOf(transfer.distributor),
                          destination: _nameOf(transfer.destinationLocation),
                          onTap: () => _openTransferDetail(transfer),
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

class _TransferCard extends StatelessWidget {
  const _TransferCard({
    required this.transfer,
    required this.stateLabel,
    required this.stateColor,
    required this.distributor,
    required this.destination,
    required this.onTap,
  });

  final VirtualTransfer transfer;
  final String stateLabel;
  final Color stateColor;
  final String distributor;
  final String destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFDDE6F2)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: const Icon(Icons.move_to_inbox, color: Color(0xFF2563EB)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                transfer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                stateLabel,
                style: TextStyle(
                  color: stateColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(distributor),
              Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${transfer.lines.length} products'),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        isThreeLine: true,
      ),
    );
  }
}
