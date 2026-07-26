import 'dart:async';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/sales/delivery_prepare.dart';
import 'package:secondary_sales/data/models/sales/sale_order_detail.dart';
import 'package:secondary_sales/data/models/inventory/warehouse.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/core/access/permission_gate.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/widgets/stock_excess_dialog.dart';

class ValidateDeliveryScreen extends StatefulWidget {
  const ValidateDeliveryScreen({
    super.key,
    required this.orderId,
    required this.orderName,
    required this.pickingId,
    required this.pickingName,
    required this.pickingState,
    this.saleType = 'primary',
  });

  final int orderId;
  final String orderName;
  final int pickingId;
  final String pickingName;
  final String pickingState;
  final String saleType;

  @override
  State<ValidateDeliveryScreen> createState() => _ValidateDeliveryScreenState();
}

class _ValidateDeliveryScreenState extends State<ValidateDeliveryScreen> {
  DeliveryPrepare? _prepare;
  int? _locationId;
  List<DeliveryLineInput> _inputs = [];
  final Map<int, List<AvailableLot>> _lotsByProduct = {};
  bool _isLoadingLots = false;
  final Map<int, Timer?> _reassignTimers = {};
  final Map<int, bool> _isReassigning = {};
  final Map<int, String?> _reassignErrors = {};

  bool get isReadOnly =>
      widget.pickingState.toLowerCase() == 'done' ||
      widget.pickingState.toLowerCase() == 'cancel';

  bool get _isSecondary => widget.saleType == 'secondary';

  @override
  void dispose() {
    for (final timer in _reassignTimers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final prepare = await context.read<PrimarySaleProvider>().prepareDelivery(
      widget.orderId,
      pickingId: widget.pickingId,
      saleType: widget.saleType,
    );
    if (!mounted || prepare == null) return;

    final inputs = prepare.picking.lines
        .map(
          (line) => DeliveryLineInput(
            move: line,
            quantityDone: isReadOnly
                ? line.quantityDone
                : line.defaultDeliveryQty,
            lots: _isSecondary
                ? []
                : (line.lotLines ?? [])
                    .map(
                      (l) => DeliveryLotInput(
                        lot: AvailableLot(
                          lotId: l.lotId ?? 0,
                          lotName: l.lotName ?? '',
                          productId: line.product?.id ?? 0,
                          availableQty: l.quantity,
                        ),
                        quantity: l.quantity,
                      ),
                    )
                    .toList(),
          ),
        )
        .toList();

    // Seed _lotsByProduct with pre-assigned lots so dropdown names display immediately
    for (final input in inputs) {
      if (input.lots.isNotEmpty) {
        final productId = input.move.product?.id;
        if (productId != null) {
          _lotsByProduct[productId] = input.lots
              .where((l) => l.lot != null)
              .map((l) => l.lot!)
              .toList();
        }
      }
    }

    setState(() {
      _prepare = prepare;
      _locationId = prepare.picking.sourceLocationId;
      _inputs = inputs;
    });

    // Fetch complete lot lists in the background so the dropdown has all options initially
    if (!isReadOnly && _locationId != null && !_isSecondary) {
      for (final input in inputs) {
        if (input.move.requiresLots) {
          final productId = input.move.product?.id;
          if (productId != null) {
            context
                .read<PrimarySaleProvider>()
                .fetchAvailableLots(
                  productId: productId,
                  locationId: _locationId,
                  pickingId: widget.pickingId,
                  saleOrderId: widget.orderId,
                )
                .then((lots) {
                  if (mounted && lots.isNotEmpty) {
                    setState(() {
                      final existing = _lotsByProduct[productId] ?? [];
                      final Map<int, AvailableLot> lotMap = {};
                      for (final lot in existing) {
                        lotMap[lot.lotId] = lot;
                      }
                      // Overwrite with fresh lots from API which have correct availableQty
                      for (final lot in lots) {
                        lotMap[lot.lotId] = lot;
                      }
                      _lotsByProduct[productId] = lotMap.values.toList();

                      // Update current inputs to reference the fresh lot objects
                      for (final input in _inputs) {
                        if (input.move.product?.id == productId) {
                          for (final lotInput in input.lots) {
                            if (lotInput.lot != null &&
                                lotMap.containsKey(lotInput.lot!.lotId)) {
                              lotInput.lot = lotMap[lotInput.lot!.lotId];
                            }
                          }
                        }
                      }
                    });
                  }
                });
          }
        }
      }
    }

    // Mirror Odoo: auto-assign FIFO for tracked products with no pre-assigned lots
    if (!isReadOnly) {
      for (final input in inputs) {
        if (input.move.requiresLots &&
            input.lots.isEmpty &&
            input.quantityDone > 0 &&
            _locationId != null) {
          _reassignLots(input);
        }
      }
    }
  }

  void _setLocation(int? locationId) {
    if (isReadOnly) return;
    setState(() {
      _locationId = locationId;
      _lotsByProduct.clear();
      _reassignErrors.clear();
      for (final input in _inputs) {
        input.lots.clear();
        if (input.quantityDone > 0) {
          _debounceReassign(input);
        }
      }
    });
  }

  void _debounceReassign(DeliveryLineInput input) {
    final productId = input.move.product?.id;
    if (productId == null) return;

    _reassignTimers[productId]?.cancel();
    _reassignTimers[productId] = Timer(const Duration(milliseconds: 500), () {
      _reassignLots(input);
    });
  }

  Future<void> _reassignLots(DeliveryLineInput input) async {
    if (isReadOnly || !input.move.requiresLots) return;

    final productId = input.move.product?.id;
    if (productId == null) return;

    setState(() {
      _isReassigning[productId] = true;
      _reassignErrors[productId] = null;
    });

    try {
      final lots = await context.read<PrimarySaleProvider>().autoAssignLots(
        productId: productId,
        quantity: input.quantityDone,
        saleOrderId: widget.orderId,
        pickingId: widget.pickingId,
        locationId: _locationId,
      );

      if (!mounted) return;

      if (lots.isEmpty) {
        // No lots returned but no exception — nothing available at this location.
        final error = context.read<PrimarySaleProvider>().error;
        if (error != null) setState(() => _reassignErrors[productId] = error);
        return;
      }

      setState(() {
        input.lots
          ..clear()
          ..addAll(lots);

        final dropdownLots = _lotsByProduct[productId] ?? [];
        for (final lotInput in lots) {
          if (lotInput.lot != null &&
              !dropdownLots.any((l) => l.lotId == lotInput.lot!.lotId)) {
            dropdownLots.add(lotInput.lot!);
          }
        }
        _lotsByProduct[productId] = dropdownLots;
      });
    } catch (e) {
      if (mounted) setState(() => _reassignErrors[productId] = e.toString());
    } finally {
      if (mounted) setState(() => _isReassigning[productId] = false);
    }
  }

  Future<void> _addLot(DeliveryLineInput input) async {
    if (isReadOnly) return;
    final productId = input.move.product?.id;
    if (productId == null) return;
    if (_locationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a source location first.')),
      );
      return;
    }

    // Always fetch fresh from API — _lotsByProduct may only contain auto-assigned lots,
    // not all available lots the user could choose from manually.
    setState(() => _isLoadingLots = true);
    final lots = await context.read<PrimarySaleProvider>().fetchAvailableLots(
      productId: productId,
      locationId: _locationId,
      pickingId: widget.pickingId,
      saleOrderId: widget.orderId,
    );
    if (!mounted) return;
    setState(() {
      final existing = _lotsByProduct[productId] ?? [];
      final Map<int, AvailableLot> lotMap = {};
      for (final lot in existing) {
        lotMap[lot.lotId] = lot;
      }
      for (final lot in lots) {
        lotMap[lot.lotId] = lot;
      }
      _lotsByProduct[productId] = lotMap.values.toList();

      // Update current inputs to reference the fresh lot objects
      for (final input in _inputs) {
        if (input.move.product?.id == productId) {
          for (final lotInput in input.lots) {
            if (lotInput.lot != null &&
                lotMap.containsKey(lotInput.lot!.lotId)) {
              lotInput.lot = lotMap[lotInput.lot!.lotId];
            }
          }
        }
      }
      _isLoadingLots = false;
    });

    if (lots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available lots found at this location.'),
        ),
      );
      return;
    }

    setState(() {
      input.lots.add(DeliveryLotInput());
    });
  }

  Future<void> _confirmDelivery() async {
    final prepare = _prepare;
    if (prepare == null || isReadOnly) return;

    final message = _validateInputs();
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    // Stock excess validation - block if any line exceeds available stock
    final excessItems = <StockExcessItem>[];
    for (final input in _inputs) {
      if (input.quantityDone > input.move.availableQty) {
        excessItems.add(StockExcessItem(
          productName: input.move.product?.name ?? 'Unknown',
          enteredQty: input.quantityDone,
          availableQty: input.move.availableQty,
        ));
      }
    }
    if (excessItems.isNotEmpty) {
      await showStockExcessValidationDialog(context, excessItems: excessItems);
      return;
    }

    if (widget.saleType == 'primary') {
      final order = await context.read<PrimarySaleProvider>().validateDelivery(
        orderId: widget.orderId,
        pickingId: prepare.picking.id,
        locationId: _locationId,
        lines: _inputs,
        saleType: widget.saleType,
        action: 'save',
      );
      if (!mounted) return;

      if (order == null) {
        final error = context.read<PrimarySaleProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Could not save delivery details.')),
        );
        return;
      }
      Navigator.of(context).pop(order);
      return;
    }

    bool hasLessQty = _inputs.any(
      (input) => input.quantityDone < input.move.orderedQty,
    );
    bool createBackorder = true;

    if (hasLessQty) {
      final bool? result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Create Backorder?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          content: const Text(
            'You have processed less products than the initial demand. '
            'Do you want to create a backorder for the remaining products?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16C083),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Create Backorder'),
            ),
          ],
        ),
      );

      if (result == null) {
        return;
      }
      createBackorder = result;
    }

    if (!mounted) return;
    final order = await context.read<PrimarySaleProvider>().validateDelivery(
      orderId: widget.orderId,
      pickingId: prepare.picking.id,
      locationId: _locationId,
      lines: _inputs,
      createBackorder: createBackorder,
      saleType: widget.saleType,
    );
    if (!mounted) return;

    if (order == null) {
      final error = context.read<PrimarySaleProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not validate delivery.')),
      );
      return;
    }
    Navigator.of(context).pop(order);
  }

  String? _validateInputs() {
    if (_inputs.every((input) => input.quantityDone <= 0)) {
      return 'Enter delivery quantity for at least one product.';
    }

    for (final input in _inputs) {
      if (input.quantityDone < 0) {
        return 'Delivery quantity cannot be negative.';
      }
      if (input.quantityDone > input.move.orderedQty) {
        return 'Delivery quantity cannot exceed ordered quantity.';
      }

      if (_isSecondary || !input.move.requiresLots || input.quantityDone <= 0) continue;

      final allocated = _allocatedQty(input);
      if ((allocated - input.quantityDone).abs() > 0.0001) {
        return 'Lot allocated quantity must match delivery quantity for ${input.move.product?.name ?? 'product'}.';
      }
    }
    return null;
  }

  double _allocatedQty(DeliveryLineInput input) {
    return input.lots.fold<double>(0, (sum, lot) => sum + lot.quantity);
  }

  void _changeLineQty(DeliveryLineInput input, double delta) {
    setState(() {
      final next = input.quantityDone + delta;
      input.quantityDone = next.clamp(0, input.move.orderedQty).toDouble();

      if (input.move.requiresLots && input.lots.isNotEmpty && delta < 0) {
        // Quantity reduced: trim existing lot allocations from the last lot first.
        // No API call — reserved stock at this picking's location is not "available"
        // to the auto-assign endpoint and would return a false insufficient-stock error.
        _trimLotsToQty(input);
      }
      // For increase: the mismatch warning appears and the user uses +/- or Add Lot.
    });
  }

  void _setLineQty(DeliveryLineInput input, double val) {
    setState(() {
      input.quantityDone = val.clamp(0, input.move.orderedQty).toDouble();

      if (input.move.requiresLots && input.lots.isNotEmpty) {
        _trimLotsToQty(input);
      }
    });
  }

  void _trimLotsToQty(DeliveryLineInput input) {
    final target = input.quantityDone;
    if (target <= 0) {
      input.lots.clear();
      return;
    }
    for (int i = input.lots.length - 1; i >= 0; i--) {
      final priorAllocated = input.lots
          .take(i)
          .fold<double>(0.0, (s, l) => s + l.quantity);
      final canTake = (target - priorAllocated).clamp(
        0.0,
        input.lots[i].quantity,
      );
      if (canTake <= 0) {
        input.lots.removeAt(i);
      } else {
        input.lots[i].quantity = canTake;
      }
    }
  }

  void _changeLotQty(DeliveryLotInput lot, double maxQty, double delta) {
    setState(() {
      final next = lot.quantity + delta;
      lot.quantity = next.clamp(0, maxQty).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrimarySaleProvider>();
    final prepare = _prepare;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: isReadOnly ? 'Delivery Details' : 'Validate Delivery',
              subtitle: '${widget.orderName} • ${widget.pickingName}',
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
                  else if (prepare == null)
                    const EmptyPanel(message: 'No delivery found')
                  else ...[
                    if (prepare.distributorName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: ssPanelDecoration(),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Delivery Address',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      prepare.distributorName!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (prepare.picking.sourceLocationName != null ||
                        prepare.picking.destinationLocationName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: ssPanelDecoration(),
                          child: Column(
                            children: [
                              if (prepare.picking.sourceLocationName != null)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.outbox,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Source Location',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            prepare.picking.sourceLocationName!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              if (prepare.picking.sourceLocationName != null &&
                                  prepare.picking.destinationLocationName !=
                                      null)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(color: AppColors.borderMuted),
                                ),
                              if (prepare.picking.destinationLocationName !=
                                  null)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.move_to_inbox,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Destination Location',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            prepare
                                                .picking
                                                .destinationLocationName!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ..._inputs.map((input) {
                      final productId = input.move.product?.id ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _DeliveryLinePanel(
                          input: input,
                          isReadOnly: isReadOnly,
                          lots: _lotsByProduct[productId] ?? [],
                          isLoadingLots: _isLoadingLots,
                          isReassigning: _isReassigning[productId] ?? false,
                          reassignError: _reassignErrors[productId],
                          allocatedQty: _allocatedQty(input),
                          isSecondary: _isSecondary,
                          onRemove: () {
                            setState(() => _inputs.remove(input));
                          },
                          onMinus: () => _changeLineQty(input, -1),
                          onPlus: () => _changeLineQty(input, 1),
                          onQuantityInput: (newVal) =>
                              _setLineQty(input, newVal),
                          onLotQtyInput: (lotInput, newVal) {
                            setState(() {
                              lotInput.quantity = newVal;
                            });
                          },
                          onAddLot: () => _addLot(input),
                          onRemoveLot: (lot) {
                            setState(() => input.lots.remove(lot));
                          },
                          onLotChanged: (lotInput, selectedLot) {
                            setState(() {
                              lotInput.lot = selectedLot;
                              if (lotInput.quantity <= 0 &&
                                  selectedLot != null) {
                                final otherAllocated = input.lots
                                    .where((l) => l != lotInput)
                                    .fold<double>(0, (s, l) => s + l.quantity);
                                final remaining =
                                    (input.quantityDone - otherAllocated).clamp(
                                      0.0,
                                      input.quantityDone,
                                    );
                                lotInput.quantity = 1.0.clamp(0.0, remaining);
                              }
                            });
                          },
                          onLotMinus: (lotInput) =>
                              _changeLotQty(lotInput, input.quantityDone, -1),
                          onLotPlus: (lotInput) {
                            final otherAllocated = input.lots
                                .where((l) => l != lotInput)
                                .fold<double>(0.0, (s, l) => s + l.quantity);
                            final maxForLot =
                                (input.quantityDone - otherAllocated).clamp(
                                  0.0,
                                  input.quantityDone,
                                );
                            _changeLotQty(lotInput, maxForLot, 1);
                          },
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            if (!isReadOnly)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFDDE6F2))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: PermissionGate(
                    resourceKey: AppAction.deliveryValidateFor(widget.saleType),
                    child: FilledButton(
                      onPressed: provider.isLoading || _prepare == null
                          ? null
                          : _confirmDelivery,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16C083),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: provider.isLoading && _prepare != null
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.saleType == 'primary'
                                  ? 'Save Delivery'
                                  : 'Confirm Delivery',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
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

class _LocationPanel extends StatefulWidget {
  const _LocationPanel({
    required this.selectedLocationId,
    required this.onChanged,
    required this.isReadOnly,
  });

  final int? selectedLocationId;
  final ValueChanged<int?> onChanged;
  final bool isReadOnly;

  @override
  State<_LocationPanel> createState() => _LocationPanelState();
}

class _LocationPanelState extends State<_LocationPanel> {
  String? _selectedLocationName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrimarySaleProvider>().fetchLocations();
    });
  }

  void _showSearchBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _LocationSearchBottomSheet(),
    ).then((selectedLoc) {
      if (selectedLoc is StockLocation) {
        setState(() {
          _selectedLocationName = selectedLoc.name;
        });
        widget.onChanged(selectedLoc.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrimarySaleProvider>();

    if (widget.selectedLocationId != null && _selectedLocationName == null) {
      final match = provider.locations.firstWhere(
        (loc) => loc.id == widget.selectedLocationId,
        orElse: () => const StockLocation(id: 0, name: ''),
      );
      if (match.id != 0) {
        _selectedLocationName = match.name;
      }
    } else if (widget.selectedLocationId == null) {
      _selectedLocationName = null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Source Location',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: widget.isReadOnly
                ? null
                : () => _showSearchBottomSheet(context),
            child: InputDecorator(
              decoration: ssInputDecoration('', Icons.location_on),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedLocationName ?? '-- Select Location --',
                      style: TextStyle(
                        color: _selectedLocationName == null
                            ? AppColors.textSecondary
                            : Colors.black,
                        fontWeight: _selectedLocationName == null
                            ? FontWeight.normal
                            : FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!widget.isReadOnly)
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textSecondary,
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

class _LocationSearchBottomSheet extends StatefulWidget {
  const _LocationSearchBottomSheet();

  @override
  State<_LocationSearchBottomSheet> createState() =>
      _LocationSearchBottomSheetState();
}

class _LocationSearchBottomSheetState
    extends State<_LocationSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      context.read<PrimarySaleProvider>().fetchLocations(search: query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrimarySaleProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Search Source Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: ssInputDecoration(
                    'Search location...',
                    Icons.search,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              Expanded(
                child: provider.isLoading && provider.locations.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : provider.locations.isEmpty
                    ? const Center(child: Text('No locations found'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: provider.locations.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          color: AppColors.borderSoft,
                        ),
                        itemBuilder: (context, index) {
                          final loc = provider.locations[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              color: Color(0xFF3B82F6),
                            ),
                            title: Text(
                              loc.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              loc.completeName ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            onTap: () => Navigator.pop(context, loc),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeliveryLinePanel extends StatelessWidget {
  const _DeliveryLinePanel({
    required this.input,
    required this.isReadOnly,
    required this.lots,
    required this.isLoadingLots,
    required this.isReassigning,
    this.reassignError,
    required this.allocatedQty,
    required this.onRemove,
    required this.onMinus,
    required this.onPlus,
    required this.onAddLot,
    required this.onRemoveLot,
    required this.onLotChanged,
    required this.onLotMinus,
    required this.onLotPlus,
    this.onQuantityInput,
    this.onLotQtyInput,
    this.isSecondary = false,
  });

  final DeliveryLineInput input;
  final bool isReadOnly;
  final List<AvailableLot> lots;
  final bool isLoadingLots;
  final bool isReassigning;
  final String? reassignError;
  final double allocatedQty;
  final VoidCallback onRemove;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onAddLot;
  final ValueChanged<DeliveryLotInput> onRemoveLot;
  final void Function(DeliveryLotInput lotInput, AvailableLot? selectedLot)
  onLotChanged;
  final ValueChanged<DeliveryLotInput> onLotMinus;
  final ValueChanged<DeliveryLotInput> onLotPlus;
  final ValueChanged<double>? onQuantityInput;
  final void Function(DeliveryLotInput lotInput, double quantity)?
  onLotQtyInput;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    final move = input.move;
    final uomName = move.uomName ?? '';
    final allocationMatches =
        (allocatedQty - input.quantityDone).abs() < 0.0001;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  move.product?.name ?? 'Product',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (!isReadOnly)
                InkWell(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Demand: ${formatQty(move.remainingQty)} $uomName',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            'Available: ${formatQty(move.availableQty)} $uomName',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Delivering',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (isReadOnly)
                Text(
                  '${formatQty(input.quantityDone)} $uomName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                )
              else
                SmallStepper(
                  value: formatQty(input.quantityDone),
                  onMinus: onMinus,
                  onPlus: onPlus,
                  onValueInput: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null && onQuantityInput != null) {
                      onQuantityInput!(parsed);
                    }
                  },
                ),
            ],
          ),
          if (!isSecondary) ...[
            const Divider(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Location Lots',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (move.requiresLots && !isReadOnly)
                  TextButton.icon(
                    onPressed: isLoadingLots || isReassigning ? null : onAddLot,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(isLoadingLots ? 'Loading' : 'Add Lot'),
                  ),
              ],
            ),
            if (!move.requiresLots)
              const Text(
                'No lot allocation required',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else if (isReassigning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (reassignError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  reassignError!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (input.lots.isEmpty)
              Text(
                isReadOnly
                    ? 'No lots allocated'
                    : 'Click "Add Lot" to allocate from source location',
                style: const TextStyle(color: AppColors.textSecondary),
              )
            else ...[
              const SizedBox(height: 8),
              ...input.lots.map(
                (lotInput) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LotAllocationRow(
                    lotInput: lotInput,
                    lots: lots,
                    isReadOnly: isReadOnly,
                    onChanged: (lot) => onLotChanged(lotInput, lot),
                    onRemove: () => onRemoveLot(lotInput),
                    onMinus: () => onLotMinus(lotInput),
                    onPlus: () => onLotPlus(lotInput),
                    onQuantityInput: (newVal) {
                      final otherAllocated = input.lots
                          .where((l) => l != lotInput)
                          .fold<double>(0.0, (s, l) => s + l.quantity);
                      final maxForLot = (input.quantityDone - otherAllocated)
                          .clamp(0.0, input.quantityDone);
                      onLotQtyInput?.call(lotInput, newVal.clamp(0, maxForLot));
                    },
                  ),
                ),
              ),
              if (!isReadOnly)
                Text(
                  'Total Allocated: ${formatQty(allocatedQty)} / '
                  '${formatQty(input.quantityDone)} $uomName'
                  '${allocationMatches ? '' : ' (Must match delivery quantity)'}',
                  style: TextStyle(
                    color: allocationMatches
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEF4444),
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LotAllocationRow extends StatelessWidget {
  const _LotAllocationRow({
    required this.lotInput,
    required this.lots,
    required this.isReadOnly,
    required this.onChanged,
    required this.onRemove,
    required this.onMinus,
    required this.onPlus,
    this.onQuantityChanged,
    this.onQuantityInput,
  });

  final DeliveryLotInput lotInput;
  final List<AvailableLot> lots;
  final bool isReadOnly;
  final ValueChanged<AvailableLot?> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<double>? onQuantityChanged;
  final ValueChanged<double>? onQuantityInput;

  @override
  Widget build(BuildContext context) {
    if (isReadOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.borderMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  lotInput.lot?.lotName ?? 'Unknown Lot',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              '${formatQty(lotInput.quantity)} units',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      );
    }

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
                  value: lotInput.lot?.lotId,
                  decoration: ssInputDecoration(
                    '-- Select Lot --',
                    Icons.inventory_2_outlined,
                  ),
                  items: lots
                      .map(
                        (lot) => DropdownMenuItem<int>(
                          value: lot.lotId,
                          child: Text(
                            '${lot.lotName} (${formatQty(lot.availableQty)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (lotId) {
                    AvailableLot? selected;
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
                  'Quantity from this lot',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SmallStepper(
                value: formatQty(lotInput.quantity),
                onMinus: onMinus,
                onPlus: onPlus,
                onValueInput: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null) {
                    if (onQuantityInput != null) {
                      onQuantityInput!(parsed);
                    } else if (onQuantityChanged != null) {
                      onQuantityChanged!(parsed);
                    }
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
