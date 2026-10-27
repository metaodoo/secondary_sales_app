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
import 'package:secondary_sales/core/widgets/expired_lots_confirmation_dialog.dart';
import 'package:secondary_sales/core/widgets/searchable_lot_selector.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

class ValidateDeliveryScreen extends StatefulWidget {
  const ValidateDeliveryScreen({
    super.key,
    required this.orderId,
    required this.orderName,
    required this.pickingId,
    required this.pickingName,
    required this.pickingState,
    this.isReceipt = false,
    this.saleType = 'primary',
    this.businessType = 'gt',
  });

  final int orderId;
  final String orderName;
  final int pickingId;
  final String pickingName;
  final String pickingState;
  final bool isReceipt;
  final String saleType;
  final String businessType;

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

  bool get _canValidate {
    if (!mounted) return true;
    final auth = context.read<AuthProvider>();
    return auth.canDo(
      AppAction.deliveryValidateFor(widget.saleType, widget.businessType),
    );
  }

  bool get _canEditActualQty {
    if (!mounted) return false;
    final auth = context.read<AuthProvider>();
    return auth.canDo(AppAction.deliveryEditActualQtyFor(widget.businessType));
  }

  bool get _canCreateReturn {
    if (!mounted) return false;
    final auth = context.read<AuthProvider>();
    return auth.canDo(AppAction.deliveryCreateReturnFor(widget.businessType));
  }

  bool get _isDeliveryReturnMode =>
      (_isMt || _isChannelSale) &&
      (widget.pickingState.toLowerCase() == 'done' ||
          _prepare?.picking.state.toLowerCase() == 'done');

  bool get _isDeliveryCountLocked =>
      _prepare?.picking.isDeliveryCountLocked ?? false;

  bool get isReadOnly =>
      widget.isReceipt ||
      widget.pickingState.toLowerCase() == 'done' ||
      widget.pickingState.toLowerCase() == 'cancel' ||
      !_canValidate;

  bool get _isMt => widget.businessType == 'mt';
  bool get _isChannelSale =>
      widget.businessType == 'cs' || widget.businessType == 'is';
  bool get _isSecondary => widget.saleType == 'secondary';
  bool get _hideLots => _isSecondary || _isMt || _isChannelSale;

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
      businessType: widget.businessType,
    );
    if (!mounted || prepare == null) return;

    final inputs = prepare.picking.lines
        .map(
          (line) => DeliveryLineInput(
            move: line,
            quantityDone: isReadOnly
                ? line.quantityDone
                : line.defaultDeliveryQty,
            lots: _hideLots
                ? []
                : (line.lotLines ?? [])
                    .where((l) => l.lotId != null && l.lotId! > 0)
                    .map(
                      (l) => DeliveryLotInput(
                        lot: AvailableLot(
                          lotId: l.lotId ?? 0,
                          lotName: l.lotName ?? '',
                          productId: line.product?.id ?? 0,
                          availableQty: l.quantity,
                          expirationDate: l.expirationDate,
                          isExpired: l.isExpired,
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
              .where((l) => l.lot != null && l.lot!.lotId > 0)
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
    final bgLocationId = _locationId ?? prepare.picking.sourceLocationId;
    if (!isReadOnly && bgLocationId != null && !_hideLots) {

      for (final input in inputs) {
        if (input.move.requiresLots) {
          final productId = input.move.product?.id;
          if (productId != null) {
            context
                .read<PrimarySaleProvider>()
                .fetchAvailableLots(
                  productId: productId,
                  locationId: bgLocationId,
                  pickingId: widget.pickingId,
                  saleOrderId: widget.orderId,
                )
                .then((lots) {
                  if (mounted && lots.isNotEmpty) {
                    setState(() {
                      final existing = _lotsByProduct[productId] ?? [];
                      final Map<int, AvailableLot> lotMap = {};
                      for (final lot in existing) {
                        if (lot.lotId > 0) lotMap[lot.lotId] = lot;
                      }
                      // Overwrite with fresh lots from API which have correct availableQty
                      for (final lot in lots) {
                        if (lot.lotId > 0) lotMap[lot.lotId] = lot;
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
    if (!isReadOnly && !_hideLots) {
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
    final locId = _locationId ?? _prepare?.picking.sourceLocationId;
    if (locId == null) {
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
      locationId: locId,
      pickingId: widget.pickingId,
      saleOrderId: widget.orderId,
    );
    if (!mounted) return;
    setState(() {
      final existing = _lotsByProduct[productId] ?? [];
      final Map<int, AvailableLot> lotMap = {};
      for (final lot in existing) {
        if (lot.lotId > 0) lotMap[lot.lotId] = lot;
      }
      for (final lot in lots) {
        if (lot.lotId > 0) lotMap[lot.lotId] = lot;
      }
      _lotsByProduct[productId] = lotMap.values.toList();

      // Update current inputs to reference the fresh lot objects
      for (final inp in _inputs) {
        if (inp.move.product?.id == productId) {
          for (final lotInput in inp.lots) {
            if (lotInput.lot != null &&
                lotMap.containsKey(lotInput.lot!.lotId)) {
              lotInput.lot = lotMap[lotInput.lot!.lotId];
            }
          }
        }
      }
      _isLoadingLots = false;
    });

    final availableLotsList = _lotsByProduct[productId] ?? [];
    if (availableLotsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available lots found for this product.'),
        ),
      );
      return;
    }

    setState(() {
      final defaultLot = availableLotsList.first;
      input.lots.add(DeliveryLotInput(
        lot: defaultLot,
        quantity: 1.0,
      ));
    });
  }

  Future<void> _confirmDelivery({bool confirm = true}) async {
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final prepare = _prepare;
    if (prepare == null || isReadOnly) return;

    final message = _validateInputs();
    if (message != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    // Secondary delivery allows native Odoo backorders when total demand exceeds
    // fresh van stock, but the damaged/QC bucket itself cannot exceed fresh stock.
    final excessItems = <StockExcessItem>[];
    for (final input in _inputs) {
      if (_isSecondary) {
        final extraQty =
            input.move.damagedExpiredQty + input.move.damageQualityQty;
        if (extraQty > input.move.availableQty) {
          excessItems.add(StockExcessItem(
            productName: input.move.product?.name ?? 'Unknown',
            enteredQty: extraQty,
            availableQty: input.move.availableQty,
            uomName: input.move.uomName ?? 'Pcs',
          ));
        }
        continue;
      }

      final effectiveAvailable =
          input.move.availableQty +
          input.move.damagedExpiredQty +
          input.move.damageQualityQty;
      if (input.quantityDone > effectiveAvailable) {
        excessItems.add(StockExcessItem(
          productName: input.move.product?.name ?? 'Unknown',
          enteredQty: input.quantityDone,
          availableQty: effectiveAvailable,
          uomName: input.move.uomName ?? 'Pcs',
        ));
      }
    }
    if (excessItems.isNotEmpty) {
      if (!mounted) return;
      await showStockExcessValidationDialog(context, excessItems: excessItems);
      return;
    }

    final saveOnly = (_isChannelSale && !confirm) ||
        (widget.saleType == 'primary' && !_isMt && !_isChannelSale);
    if (saveOnly) {
      if (!mounted) return;
      final order = await context.read<PrimarySaleProvider>().validateDelivery(
        orderId: widget.orderId,
        pickingId: prepare.picking.id,
        locationId: _locationId,
        lines: _inputs,
        saleType: widget.saleType,
        businessType: widget.businessType,
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

    if (!mounted) return;
    SaleOrderDetail? order;
    try {
      order = await context.read<PrimarySaleProvider>().validateDelivery(
        orderId: widget.orderId,
        pickingId: prepare.picking.id,
        locationId: _locationId,
        lines: _inputs,
        createBackorder: false,
        saleType: widget.saleType,
        businessType: widget.businessType,
        skipExpired: false,
      );
    } on ExpiredLotsConfirmationException catch (e) {
      if (!mounted) return;
      final bool confirmed = await showExpiredLotsConfirmationDialog(
        context,
        expiredLots: e.expiredLots,
      );
      if (confirmed && mounted) {
        try {
          order = await context.read<PrimarySaleProvider>().validateDelivery(
            orderId: widget.orderId,
            pickingId: prepare.picking.id,
            locationId: _locationId,
            lines: _inputs,
            createBackorder: false,
            saleType: widget.saleType,
            businessType: widget.businessType,
            skipExpired: true,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
          return;
        }
      } else {
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
      return;
    }
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

      if (_hideLots || !input.move.requiresLots || input.quantityDone <= 0) continue;

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

    });
  }

  void _setLineQty(DeliveryLineInput input, double val) {
    setState(() {
      input.quantityDone = val.clamp(0, input.move.orderedQty).toDouble();

    });
  }

  void _changeLotQty(DeliveryLotInput lot, double maxQty, double delta) {
    setState(() {
      final next = lot.quantity + delta;
      lot.quantity = next.clamp(0, double.infinity).toDouble();
    });
  }

  Future<void> _openCreateOrUpdateReturnDialog() async {
    for (final input in _inputs) {
      if (input.actualDeliveredQty < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Actual delivered quantity cannot be negative for ${input.move.product?.name ?? 'item'}.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (input.actualDeliveredQty > input.quantityDone) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Actual delivered (${formatQty(input.actualDeliveredQty)}) cannot exceed validated (${formatQty(input.quantityDone)}) for ${input.move.product?.name ?? 'item'}.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final returnLines = _inputs.where((i) => i.returnQty > 0).toList();
    final isUpdate = _prepare?.picking.hasDeliveryReturn == true;
    final noteController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      isUpdate ? Icons.sync : Icons.assignment_return,
                      color: const Color(0xFFD97706),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isUpdate ? 'Update Delivery Return' : 'Create Delivery Return',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (returnLines.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'All items marked as fully accepted. If an existing return picking exists, its return lines will be cleared.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  )
                else ...[
                  const Text(
                    'Shortage items to return to warehouse:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderSoft),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: returnLines.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (c, idx) {
                        final item = returnLines[idx];
                        return ListTile(
                          dense: true,
                          title: Text(
                            item.move.product?.name ?? 'Product',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            'Validated: ${formatQty(item.quantityDone)} | Accepted: ${formatQty(item.actualDeliveredQty)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Return: ${formatQty(item.returnQty)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: ssInputDecoration(
                    'Reason / Return note (optional)...',
                    Icons.note_alt_outlined,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: Text(
                      isUpdate ? 'Confirm & Update Return' : 'Confirm & Create Return',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      final provider = context.read<PrimarySaleProvider>();
      final res = await provider.createOrUpdateDeliveryReturn(
        pickingId: widget.pickingId,
        lines: _inputs,
        note: noteController.text.trim(),
      );
      if (!mounted) return;
      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUpdate
                  ? 'Delivery return updated successfully.'
                  : 'Delivery return created successfully.',
            ),
            backgroundColor: const Color(0xFF16C083),
          ),
        );
        _load();
      } else if (provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              title: _isDeliveryReturnMode
                  ? 'Delivery & Return'
                  : (isReadOnly ? 'Delivery Details' : 'Validate Delivery'),
              subtitle: '${widget.orderName} • ${widget.pickingName}',
              leading: IconButton(
                tooltip: 'Back',
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
                    if (_isDeliveryReturnMode && prepare.picking.hasDeliveryReturn)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.assignment_return,
                                    color: Color(0xFF2563EB),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Return: ${prepare.picking.returnPickingName ?? ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1E40AF),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isDeliveryCountLocked
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (prepare.picking.deliveryReturnState ??
                                              'draft')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: _isDeliveryCountLocked
                                            ? const Color(0xFF166534)
                                            : const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isDeliveryCountLocked
                                    ? 'Return picking has been validated by Supply Chain. Delivery count and returns are permanently locked.'
                                    : 'Pending Supply Chain validation. You can update delivery counts if recounted.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isDeliveryCountLocked
                                      ? const Color(0xFF166534)
                                      : const Color(0xFF1E40AF),
                                ),
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
                          showActualDeliveredQty: _isDeliveryReturnMode,
                          canEditActualQty: _canEditActualQty,
                          isDeliveryCountLocked: _isDeliveryCountLocked,
                          onActualDeliveredQtyChanged: (newVal) {
                            setState(() {
                              input.actualDeliveredQty = newVal;
                            });
                          },
                          lots: _lotsByProduct[productId] ?? [],
                          isLoadingLots: _isLoadingLots,
                          isReassigning: _isReassigning[productId] ?? false,
                          reassignError: _reassignErrors[productId],
                          allocatedQty: _allocatedQty(input),
                          hideLots: _hideLots,
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
                                lotInput.quantity = 1.0;
                              }
                            });
                          },
                          onLotMinus: (lotInput) =>
                              _changeLotQty(lotInput, double.infinity, -1),
                          onLotPlus: (lotInput) =>
                              _changeLotQty(lotInput, double.infinity, 1),
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
                child: _isChannelSale
                    ? Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: provider.isLoading || _prepare == null
                                  ? null
                                  : () => _confirmDelivery(confirm: false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF16C083)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: const Text(
                                'Save Delivery',
                                style: TextStyle(
                                  color: Color(0xFF16C083),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: PermissionGate(
                              resourceKey: AppAction.deliveryValidateFor(
                                widget.saleType,
                                widget.businessType,
                              ),
                              child: FilledButton(
                                onPressed: provider.isLoading || _prepare == null
                                    ? null
                                    : () => _confirmDelivery(confirm: true),
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
                                    : const Text(
                                        'Confirm Delivery',
                                        style: TextStyle(fontWeight: FontWeight.w800),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: PermissionGate(
                          resourceKey: AppAction.deliveryValidateFor(
                            widget.saleType,
                            widget.businessType,
                          ),
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
                                    (widget.saleType == 'primary' && !_isMt)
                                        ? 'Save Delivery'
                                        : 'Confirm Delivery',
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ),
                      ),
              )
            else if (_isDeliveryReturnMode && _canCreateReturn && !_isDeliveryCountLocked)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFDDE6F2))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: provider.isLoading ? null : _openCreateOrUpdateReturnDialog,
                    icon: Icon(
                      prepare?.picking.hasDeliveryReturn == true
                          ? Icons.sync
                          : Icons.assignment_return,
                    ),
                    label: Text(
                      prepare?.picking.hasDeliveryReturn == true
                          ? 'Update Return'
                          : 'Create Return',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
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
                      tooltip: 'Close',
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
    this.hideLots = false,
    this.showActualDeliveredQty = false,
    this.canEditActualQty = false,
    this.isDeliveryCountLocked = false,
    this.onActualDeliveredQtyChanged,
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
  final bool hideLots;
  final bool showActualDeliveredQty;
  final bool canEditActualQty;
  final bool isDeliveryCountLocked;
  final ValueChanged<double>? onActualDeliveredQtyChanged;

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
          if (!hideLots) ...[
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
                      onLotQtyInput?.call(lotInput, newVal.clamp(0, double.infinity));
                    },
                  ),
                ),
              ),
              if (!isReadOnly)
                Text(
                  'Total Allocated: ${formatQty(allocatedQty)} / '
                  '${formatQty(input.quantityDone)} $uomName',
                  style: TextStyle(
                    color: allocationMatches
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEF4444),
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ],
          if (showActualDeliveredQty) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actual Delivered',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (input.returnQty > 0)
                        Text(
                          'Shortage: ${formatQty(input.returnQty)} $uomName',
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (canEditActualQty && !isDeliveryCountLocked)
                  SmallStepper(
                    value: formatQty(input.actualDeliveredQty),
                    onMinus: () {
                      final next = (input.actualDeliveredQty - 1).clamp(
                        0.0,
                        input.quantityDone,
                      );
                      onActualDeliveredQtyChanged?.call(next);
                    },
                    onPlus: () {
                      final next = (input.actualDeliveredQty + 1).clamp(
                        0.0,
                        input.quantityDone,
                      );
                      onActualDeliveredQtyChanged?.call(next);
                    },
                    onValueInput: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null) {
                        final next = parsed.clamp(0.0, input.quantityDone);
                        onActualDeliveredQtyChanged?.call(next);
                      }
                    },
                  )
                else
                  Text(
                    '${formatQty(input.actualDeliveredQty)} $uomName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
              ],
            ),
            if (input.returnQty > 0)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.assignment_return,
                      size: 16,
                      color: Color(0xFFB45309),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Difference of ${formatQty(input.returnQty)} $uomName will return to warehouse',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    this.onQuantityInput,
  });

  final DeliveryLotInput lotInput;
  final List<AvailableLot> lots;
  final bool isReadOnly;
  final ValueChanged<AvailableLot?> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<double>? onQuantityInput;

  @override
  Widget build(BuildContext context) {
    if (isReadOnly) {
      final lot = lotInput.lot;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.borderMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      lot?.lotName ?? 'Unknown Lot',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (lot?.isExpired == true) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Expired',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ] else if (lot?.expirationDate != null && lot!.expirationDate!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(${lot.expirationDate})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
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

    final isCurrentLotExpired = lotInput.lot?.isExpired == true;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: isCurrentLotExpired
            ? Border.all(color: Colors.amber.shade300)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GenericSearchableLotSelector<AvailableLot>(
                  selectedItem: (lotInput.lot != null &&
                          lots.any((l) => l.lotId == lotInput.lot!.lotId && l.lotId > 0))
                      ? lotInput.lot
                      : null,
                  items: lots.where((lot) => lot.lotId > 0).toList(),
                  getLabel: (lot) => lot.availableQty > 0
                      ? '${lot.lotName} (${formatQty(lot.availableQty)} avail)'
                      : lot.lotName,
                  getSubtitle: (lot) => lot.expirationDate != null && lot.expirationDate!.isNotEmpty
                      ? 'Exp: ${lot.expirationDate}'
                      : null,
                  getBadgeText: (lot) => lot.isExpired ? 'Expired' : null,
                  getBadgeColor: (lot) => lot.isExpired ? Colors.red.shade700 : null,
                  modalTitle: 'Select Lot Number',
                  hintText: '-- Select Lot --',
                  allowClear: true,
                  clearLabel: '-- Clear Lot Selection --',
                  onChanged: (selected) {
                    onChanged(selected);
                  },
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onRemove,
                icon: const Icon(Icons.close, color: Color(0xFFEF4444)),
              ),
            ],
          ),
          if (isCurrentLotExpired)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, bottom: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Warning: Selected lot is expired'
                      '${lotInput.lot?.expirationDate != null ? ' (${lotInput.lot!.expirationDate})' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
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
                  if (parsed != null && onQuantityInput != null) {
                    onQuantityInput!(parsed);
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
