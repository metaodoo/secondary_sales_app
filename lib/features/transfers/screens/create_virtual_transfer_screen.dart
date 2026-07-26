import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/inventory/virtual_location.dart';
import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/features/transfers/transfer_provider.dart';
import 'package:secondary_sales/features/transfers/screens/transfer_product_selection_screen.dart';
import 'package:secondary_sales/features/transfers/screens/virtual_transfer_detail_screen.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/widgets/stock_excess_dialog.dart';

class CreateVirtualTransferScreen extends StatefulWidget {
  const CreateVirtualTransferScreen({super.key});

  @override
  State<CreateVirtualTransferScreen> createState() =>
      _CreateVirtualTransferScreenState();
}

class _CreateVirtualTransferScreenState
    extends State<CreateVirtualTransferScreen> {
  int? _selectedDestinationId;
  final List<VirtualTransferLineEntry> _lines = [];
  final Map<int, List<TransferLot>> _lotsByProduct = {};
  bool _isLoadingLots = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransferProvider>().prepareVirtualTransfer();
    });
  }

  Future<void> _selectProducts() async {
    if (_selectedDestinationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a Van Loading Location')),
      );
      return;
    }

    final selected = await Navigator.push<List<VirtualTransferLineEntry>>(
      context,
      MaterialPageRoute(
        builder: (_) => TransferProductSelectionScreen(
          destinationLocationId: _selectedDestinationId!,
          initialLines: _lines,
        ),
      ),
    );
    if (selected == null) return;
    setState(() {
      _lines
        ..clear()
        ..addAll(selected);
      // Clear lots that are no longer in lines
      final lineProductIds = _lines.map((l) => l.product.id).toSet();
      _lotsByProduct.removeWhere((id, _) => !lineProductIds.contains(id));
    });
  }

  Future<void> _addLot(VirtualTransferLineEntry line) async {
    final productId = line.product.id;
    if (_selectedDestinationId == null) return;

    if (!_lotsByProduct.containsKey(productId)) {
      setState(() => _isLoadingLots = true);
      final lots = await context.read<TransferProvider>().fetchTransferLots(
        productId,
        destinationLocationId: _selectedDestinationId!,
      );
      if (!mounted) return;
      setState(() {
        _lotsByProduct[productId] = lots;
        _isLoadingLots = false;
      });
    }

    final lots = _lotsByProduct[productId] ?? [];
    if (lots.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No available lots found.')));
      return;
    }

    setState(() {
      line.lotLines.add(TransferLotInput());
    });
  }

  void _changeLotQty(TransferLotInput lotInput, double maxQty, double delta) {
    setState(() {
      final next = lotInput.quantity + delta;
      lotInput.quantity = next.clamp(0, maxQty).toDouble();
    });
  }

  double _allocatedQty(VirtualTransferLineEntry line) {
    return line.lotLines.fold<double>(0, (sum, lot) => sum + lot.quantity);
  }

  Future<void> _createTransfer() async {
    if (_selectedDestinationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a Van Loading Location')),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one product')));
      return;
    }

    // Validate lot allocations
    for (final line in _lines) {
      if (line.product.requiresLots && line.lotLines.isNotEmpty) {
        final allocated = _allocatedQty(line);
        if ((allocated - line.quantity).abs() > 0.0001) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Lot allocation for ${line.product.name} must match transfer quantity.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    // Stock excess validation - block if any line exceeds available stock
    final excessItems = <StockExcessItem>[];
    for (final line in _lines) {
      if (line.quantity > line.product.availableQty) {
        excessItems.add(StockExcessItem(
          productName: line.product.name,
          enteredQty: line.quantity,
          availableQty: line.product.availableQty,
          uomName: line.product.uomName,
        ));
      }
    }
    if (excessItems.isNotEmpty) {
      await showStockExcessValidationDialog(context, excessItems: excessItems);
      return;
    }

    final transfer = await context
        .read<TransferProvider>()
        .createVirtualTransfer(
          destinationLocationId: _selectedDestinationId!,
          lines: _lines,
        );

    if (!mounted) return;
    if (transfer == null) {
      final error = context.read<TransferProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to create transfer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VirtualTransferDetailScreen(initialTransfer: transfer),
      ),
    );
  }

  String _nameOf(Map<String, dynamic>? value) {
    final name = value?['name'];
    return name == null || name.toString().trim().isEmpty
        ? '-'
        : name.toString();
  }

  List<VirtualLocation> _uniqueDestinations(List<VirtualLocation> values) {
    final byId = <int, VirtualLocation>{};
    for (final value in values) {
      if (value.id > 0) {
        byId[value.id] = value;
      }
    }
    return byId.values.toList();
  }

  VirtualLocation? _destinationById(
    List<VirtualLocation> destinations,
    int? id,
  ) {
    if (id == null) return null;
    for (final destination in destinations) {
      if (destination.id == id) {
        return destination;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransferProvider>();
    final prepare = provider.transferPrepare;
    final destinations = _uniqueDestinations(
      prepare?.destinationLocations ?? [],
    );

    if (destinations.isEmpty) {
      _selectedDestinationId = null;
    } else if (_selectedDestinationId == null ||
        !destinations.any(
          (location) => location.id == _selectedDestinationId,
        )) {
      _selectedDestinationId = destinations.first.id;
    }
    final selectedDestination = _destinationById(
      destinations,
      _selectedDestinationId,
    );
    final distributor =
        selectedDestination?.distributor ?? prepare?.distributor;
    final source = distributor?['customer_stock_location'];
    final sourceLocation = source is Map
        ? source.cast<String, dynamic>()
        : prepare?.sourceLocation;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: 'Virtual Transfer',
              subtitle: 'Load stock into van',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (provider.error != null) ErrorPanel(provider.error!),
                  if (provider.isLoading && prepare == null)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: ssPanelDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(
                            label: 'Distributor',
                            value: _nameOf(distributor),
                          ),
                          _InfoRow(
                            label: 'Source',
                            value: _nameOf(sourceLocation),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Destination',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedDestinationId,
                            isExpanded: true,
                            decoration: ssInputDecoration(
                              'Select Van Loading Location',
                              Icons.inventory_2,
                            ),
                            items: destinations.map((location) {
                              return DropdownMenuItem(
                                value: location.id,
                                child: Text(
                                  location.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDestinationId = value;
                                _lines.clear();
                                _lotsByProduct.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectProducts,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Products'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_lines.isEmpty)
                      const EmptyPanel(message: 'No transfer products added')
                    else ...[
                      const Text(
                        'Transfer Lines',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._lines.map(
                        (line) => _TransferLineCard(
                          line: line,
                          onRemove: () => setState(() => _lines.remove(line)),
                          onChanged: () => setState(() {}),
                          lots: _lotsByProduct[line.product.id] ?? [],
                          isLoadingLots: _isLoadingLots,
                          onAddLot: () => _addLot(line),
                          onRemoveLot: (lot) =>
                              setState(() => line.lotLines.remove(lot)),
                          onLotChanged: (lotInput, selectedLot) {
                            setState(() {
                              lotInput.lot = selectedLot;
                              if (lotInput.quantity <= 0 &&
                                  selectedLot != null) {
                                lotInput.quantity = 1
                                    .clamp(0, selectedLot.availableQty)
                                    .toDouble();
                              }
                            });
                          },
                          onLotMinus: (lotInput) => _changeLotQty(
                            lotInput,
                            lotInput.lot?.availableQty ?? line.quantity,
                            -1,
                          ),
                          onLotPlus: (lotInput) => _changeLotQty(
                            lotInput,
                            lotInput.lot?.availableQty ?? line.quantity,
                            1,
                          ),
                          allocatedQty: _allocatedQty(line),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: provider.isLoading ? null : _createTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: provider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Transfer',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 92,
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

class _TransferLineCard extends StatelessWidget {
  const _TransferLineCard({
    required this.line,
    required this.onRemove,
    required this.onChanged,
    required this.lots,
    required this.isLoadingLots,
    required this.onAddLot,
    required this.onRemoveLot,
    required this.onLotChanged,
    required this.onLotMinus,
    required this.onLotPlus,
    required this.allocatedQty,
  });

  final VirtualTransferLineEntry line;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final List<TransferLot> lots;
  final bool isLoadingLots;
  final VoidCallback onAddLot;
  final ValueChanged<TransferLotInput> onRemoveLot;
  final void Function(TransferLotInput lotInput, TransferLot? selectedLot)
  onLotChanged;
  final ValueChanged<TransferLotInput> onLotMinus;
  final ValueChanged<TransferLotInput> onLotPlus;
  final double allocatedQty;

  @override
  Widget build(BuildContext context) {
    final allocationMatches = (allocatedQty - line.quantity).abs() < 0.0001;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, color: Colors.red),
              ),
            ],
          ),
          Text(
            'Available: ${line.product.availableQty.toStringAsFixed(0)} ${line.product.uomName}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SmallStepper(
                value: line.quantity.toStringAsFixed(0),
                onMinus: () {
                  if (line.quantity > 1) {
                    line.quantity--;
                    onChanged();
                  }
                },
                onPlus: () {
                  line.quantity++;
                  onChanged();
                },
                onValueInput: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null) {
                    line.quantity = parsed.clamp(1, double.infinity);
                    onChanged();
                  }
                },
              ),
              const Spacer(),
              Text(
                '${line.quantity.toStringAsFixed(0)} ${line.product.uomName}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (line.product.requiresLots) ...[
            const Divider(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Manual Lot Selection',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: isLoadingLots ? null : onAddLot,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(isLoadingLots ? 'Loading' : 'Select Lot'),
                ),
              ],
            ),
            if (line.lotLines.isEmpty)
              const Text(
                'Lots will be allocated automatically if none selected.',
                style: TextStyle(color: Color(0xFF2563EB), fontSize: 12),
              )
            else ...[
              const SizedBox(height: 8),
              ...line.lotLines.map(
                (lotInput) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TransferLotAllocationRow(
                    lotInput: lotInput,
                    lots: lots,
                    onChanged: (lot) => onLotChanged(lotInput, lot),
                    onRemove: () => onRemoveLot(lotInput),
                    onMinus: () => onLotMinus(lotInput),
                    onPlus: () => onLotPlus(lotInput),
                    onQuantityChanged: (newVal) {
                      final maxQty = lotInput.lot?.availableQty ?? line.quantity;
                      lotInput.quantity = newVal.clamp(0, maxQty);
                      onChanged();
                    },
                  ),
                ),
              ),
              Text(
                'Total Allocated: ${line.quantity.toStringAsFixed(0)} / '
                '${allocatedQty.toStringAsFixed(0)} '
                '${allocationMatches ? '' : '(Must match)'}',
                style: TextStyle(
                  color: allocationMatches
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFEF4444),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TransferLotAllocationRow extends StatelessWidget {
  const _TransferLotAllocationRow({
    required this.lotInput,
    required this.lots,
    required this.onChanged,
    required this.onRemove,
    required this.onMinus,
    required this.onPlus,
    this.onQuantityChanged,
  });

  final TransferLotInput lotInput;
  final List<TransferLot> lots;
  final ValueChanged<TransferLot?> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<double>? onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: lotInput.lot?.lotId,
                  isExpanded: true,
                  decoration: ssInputDecoration(
                    '-- Select Lot --',
                    Icons.inventory_2_outlined,
                  ),
                  items: lots
                      .map(
                        (lot) => DropdownMenuItem<int>(
                          value: lot.lotId,
                          child: Text(
                            lot.lotName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (lotId) {
                    TransferLot? selected;
                    for (final lot in lots) {
                      if (lot.lotId == lotId) {
                        selected = lot;
                        break;
                      }
                    }
                    onChanged(selected);
                  },
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, color: Color(0xFFEF4444)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Quantity',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SmallStepper(
                value: lotInput.quantity.toStringAsFixed(0),
                onMinus: onMinus,
                onPlus: onPlus,
                onValueInput: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && onQuantityChanged != null) {
                    onQuantityChanged!(parsed);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
