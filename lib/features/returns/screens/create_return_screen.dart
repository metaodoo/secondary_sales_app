import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/features/returns/return_provider.dart';
import 'package:secondary_sales/features/returns/screens/return_product_selection_screen.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

class CreateReturnScreen extends StatefulWidget {
  final int? returnId;
  final String moduleType;

  const CreateReturnScreen({
    super.key,
    this.returnId,
    this.moduleType = 'primary',
  });

  @override
  State<CreateReturnScreen> createState() => _CreateReturnScreenState();
}

class _CreateReturnScreenState extends State<CreateReturnScreen> {
  final List<VirtualTransferLineEntry> _lines = [];
  final Map<int, List<TransferLot>> _lotsByProduct = {};
  bool _isLoadingLots = false;
  Map<String, dynamic>? _prepareData;
  bool _isPreparing = true;
  bool _isReadOnly = false;

  final TextEditingController _challanNumberController =
      TextEditingController();
  String? _selectedDamageType;

  @override
  void dispose() {
    _challanNumberController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareReturn();
    });
  }

  Future<void> _prepareReturn({int? distributorId}) async {
    final provider = context.read<ReturnProvider>();

    if (widget.returnId != null) {
      final details = await provider.getReturnDetails(
        widget.returnId!,
        type: widget.moduleType,
      );
      if (mounted && details != null) {
        setState(() {
          _isReadOnly =
              details['state'] == 'done' || details['state'] == 'cancel';
          _challanNumberController.text = details['challan_number'] ?? '';
          _selectedDamageType = details['damage_type'];
          _prepareData = {
            'distributor': details['distributor'],
            'source_location': details['source_location'],
            'warehouse': details['destination_location'],
          };

          final linesData = details['lines'] as List<dynamic>? ?? [];
          for (final ld in linesData) {
            final productData = ld['product'];
            if (productData == null) continue;

            final product = TransferProduct.fromMap(productData);
            final qty = (ld['quantity'] as num?)?.toDouble() ?? 0.0;

            final entry = VirtualTransferLineEntry(
              product: product,
              quantity: qty,
              soQty: (ld['so_qty'] as num?)?.toDouble(),
              qcQty: (ld['qc_qty'] as num?)?.toDouble(),
            );

            final lotLinesData = ld['lot_lines'] as List<dynamic>? ?? [];
            for (final ll in lotLinesData) {
              final lotData = ll['lot'];
              if (lotData != null) {
                final lotId = lotData['id'] as int;
                final lotName = lotData['name'] as String;
                final lotQty = (ll['quantity'] as num?)?.toDouble() ?? 0.0;
                final soQty = (ll['so_qty'] as num?)?.toDouble();
                final qcQty = (ll['qc_qty'] as num?)?.toDouble();
                final lotAvail =
                    (lotData['available_qty'] as num?)?.toDouble() ?? lotQty;

                final maxCurrent = [
                  lotQty,
                  soQty ?? 0.0,
                  qcQty ?? 0.0,
                ].reduce((a, b) => a > b ? a : b);
                final finalAvail = lotAvail > maxCurrent
                    ? lotAvail
                    : maxCurrent;

                final tLot = TransferLot(
                  lotId: lotId,
                  lotName: lotName,
                  availableQty: finalAvail,
                );

                entry.lotLines.add(
                  TransferLotInput()
                    ..lot = tLot
                    ..quantity = lotQty
                    ..soQty = soQty
                    ..qcQty = qcQty,
                );
              }
            }
            _lines.add(entry);
          }
          _isPreparing = false;
        });
      }
    } else {
      setState(() {
        _isPreparing = true;
      });
      final data = await provider.prepareReturn(distributorId: distributorId);
      if (mounted && data != null) {
        setState(() {
          _prepareData = data;
        });

        final resolvedDistributorId = data['distributor']?['id'] as int?;
        if (resolvedDistributorId != null) {
          final products = await provider.fetchReturnProducts(
            distributorId: resolvedDistributorId,
          );
          if (mounted && products != null) {
            final auth = context.read<AuthProvider>();
            setState(() {
              _lines.clear();
              for (final p in products) {
                final product = TransferProduct.fromMap(p);
                if (product.availableQty > 0) {
                  _lines.add(
                    VirtualTransferLineEntry(
                      product: product,
                      quantity: product.availableQty,
                      soQty: auth.canEditSoQty ? product.availableQty : null,
                      qcQty: auth.canEditQcQty ? product.availableQty : null,
                    ),
                  );
                }
              }
            });
          }
        }

        setState(() {
          _isPreparing = false;
        });
      }
    }
  }

  Future<void> _selectProducts() async {
    final distributorId = _prepareData?['distributor']?['id'] as int?;
    if (distributorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Distributor not loaded properly.')),
      );
      return;
    }

    final selected = await Navigator.push<List<VirtualTransferLineEntry>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReturnProductSelectionScreen(
          distributorId: distributorId,
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
    final distributorId = _prepareData?['distributor']?['id'] as int?;
    if (distributorId == null) return;

    if (!_lotsByProduct.containsKey(productId)) {
      setState(() => _isLoadingLots = true);
      final res = await context.read<ReturnProvider>().fetchReturnProductLots(
        productId,
        distributorId: distributorId,
      );
      if (!mounted) return;

      final lotsData =
          (res?['data'] as List<dynamic>?)
              ?.map((l) => TransferLot.fromMap(l as Map<String, dynamic>))
              .toList() ??
          [];

      setState(() {
        _lotsByProduct[productId] = lotsData;
        _isLoadingLots = false;
      });
    }

    final lots = _lotsByProduct[productId] ?? [];
    if (lots.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available lots found for this product.'),
        ),
      );
      return;
    }

    setState(() {
      line.lotLines.add(TransferLotInput());
    });
  }

  void _changeLotQty(TransferLotInput lotInput, double maxQty, double delta) {
    final auth = context.read<AuthProvider>();
    setState(() {
      if (auth.canEditSoQty) {
        final current = lotInput.soQty ?? lotInput.quantity;
        final next = current + delta;
        lotInput.soQty = next.clamp(0, maxQty).toDouble();
      } else if (auth.canEditQcQty) {
        final current = lotInput.qcQty ?? lotInput.quantity;
        final next = current + delta;
        lotInput.qcQty = next.clamp(0, maxQty).toDouble();
      } else {
        final next = lotInput.quantity + delta;
        lotInput.quantity = next.clamp(0, maxQty).toDouble();
      }
    });
  }

  double _allocatedQty(VirtualTransferLineEntry line) {
    return line.lotLines.fold<double>(0, (sum, lot) => sum + lot.quantity);
  }

  double _allocatedSoQty(VirtualTransferLineEntry line) {
    return line.lotLines.fold<double>(
      0,
      (sum, lot) => sum + (lot.soQty ?? lot.quantity),
    );
  }

  double _allocatedQcQty(VirtualTransferLineEntry line) {
    return line.lotLines.fold<double>(
      0,
      (sum, lot) => sum + (lot.qcQty ?? lot.quantity),
    );
  }

  Future<void> _createReturn() async {
    final distributorId = _prepareData?['distributor']?['id'] as int?;
    if (distributorId == null) return;

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one product')));
      return;
    }

    final auth = context.read<AuthProvider>();
    for (final line in _lines) {
      final targetQty = auth.canEditSoQty
          ? (line.soQty ?? 0.0)
          : (auth.canEditQcQty ? (line.qcQty ?? 0.0) : line.quantity);

      if (line.product.requiresLots && targetQty > 0) {
        if (line.lotLines.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please select lots for ${line.product.name} (Auto-allocate is disabled for returns)',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        final allocated = auth.canEditSoQty
            ? _allocatedSoQty(line)
            : (auth.canEditQcQty ? _allocatedQcQty(line) : _allocatedQty(line));

        if ((allocated - targetQty).abs() > 0.0001) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Lot allocation for ${line.product.name} must match return quantity.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    final linesData = _lines.map((line) {
      final qty = line.product.tracking != 'none'
          ? _allocatedQty(line)
          : line.quantity;
      final soQty = line.product.tracking != 'none'
          ? _allocatedSoQty(line)
          : line.soQty;
      final qcQty = line.product.tracking != 'none'
          ? _allocatedQcQty(line)
          : line.qcQty;

      return {
        'product_id': line.product.id,
        'product_uom_qty': 0.0,
        'quantity': qty,
        if (soQty != null && soQty > 0) 'so_qty': soQty,
        if (qcQty != null && qcQty > 0) 'qc_qty': qcQty,
        'lot_lines': line.lotLines
            .where((l) => l.lot != null)
            .map(
              (l) => {
                'lot_id': l.lot!.lotId,
                'product_uom_qty': 0.0,
                'quantity': l.quantity,
                if (l.soQty != null && l.soQty! > 0) 'so_qty': l.soQty,
                if (l.qcQty != null && l.qcQty! > 0) 'qc_qty': l.qcQty,
              },
            )
            .toList(),
      };
    }).toList();

    Map<String, dynamic>? result;
    if (widget.returnId != null) {
      result = await context.read<ReturnProvider>().updateReturnDelivery(
        widget.returnId!,
        lines: linesData,
        type: widget.moduleType,
        challanNumber: _challanNumberController.text,
        damageType: _selectedDamageType,
      );
    } else {
      result = await context.read<ReturnProvider>().createReturnDelivery(
        lines: linesData,
        distributorId: distributorId,
        type: widget.moduleType,
        challanNumber: _challanNumberController.text,
        damageType: _selectedDamageType,
      );
    }

    if (!mounted) return;
    if (result == null) {
      final error = context.read<ReturnProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to create return delivery'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Return delivery created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _runAction(String action) async {
    if (widget.returnId == null) return;

    setState(() => _isPreparing = true);

    try {
      if (action == 'validate') {
        // Save first!
        final linesData = _lines.map((line) {
          final qty = line.product.tracking != 'none'
              ? _allocatedQty(line)
              : line.quantity;
          final soQty = line.product.tracking != 'none'
              ? _allocatedSoQty(line)
              : line.soQty;
          final qcQty = line.product.tracking != 'none'
              ? _allocatedQcQty(line)
              : line.qcQty;

          return {
            'product_id': line.product.id,
            'product_uom_qty': 0.0,
            'quantity': qty,
            if (soQty != null && soQty > 0) 'so_qty': soQty,
            if (qcQty != null && qcQty > 0) 'qc_qty': qcQty,
            'lot_lines': line.lotLines
                .where((l) => l.lot != null)
                .map(
                  (l) => {
                    'lot_id': l.lot!.lotId,
                    'product_uom_qty': 0.0,
                    'quantity': l.quantity,
                    if (l.soQty != null && l.soQty! > 0) 'so_qty': l.soQty,
                    if (l.qcQty != null && l.qcQty! > 0) 'qc_qty': l.qcQty,
                  },
                )
                .toList(),
          };
        }).toList();

        final saveRes = await context
            .read<ReturnProvider>()
            .updateReturnDelivery(
              widget.returnId!,
              lines: linesData,
              type: widget.moduleType,
              challanNumber: _challanNumberController.text,
              damageType: _selectedDamageType,
            );
        if (saveRes == null) {
          final err =
              context.read<ReturnProvider>().error ??
              'Save failed before validation';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
          return;
        }
      }

      final res = await context.read<ReturnProvider>().executeReturnAction(
        widget.returnId!,
        action,
      );
      if (!mounted) return;

      if (res == null) {
        final err = context.read<ReturnProvider>().error ?? 'Action failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Return ${action == 'validate' ? 'validated' : 'cancelled'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isPreparing = false);
    }
  }

  String _nameOf(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value['name']?.toString() ?? '-';
    }
    return value?.toString() ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReturnProvider>();
    final auth = context.watch<AuthProvider>();
    final canEditSoQty = auth.canEditSoQty;
    final canEditQcQty = auth.canEditQcQty;
    final canEditEffectiveQty = auth.canEditEffectiveQty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Returns',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isPreparing
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (provider.error != null && _lines.isEmpty)
                          ErrorPanel(provider.error!),

                        // Header Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDDE6F2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Distributor',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (!_isReadOnly &&
                                  _prepareData?['distributors'] is List &&
                                  (_prepareData?['distributors'] as List)
                                          .length >
                                      1)
                                DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  value:
                                      _prepareData?['distributor']?['id']
                                          as int?,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    fillColor: Colors.white,
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFDDE6F2),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFDDE6F2),
                                      ),
                                    ),
                                  ),
                                  items: (_prepareData?['distributors'] as List)
                                      .map((d) {
                                        final map = d as Map<dynamic, dynamic>;
                                        return DropdownMenuItem<int>(
                                          value: map['id'] as int?,
                                          child: Text(
                                            map['name']?.toString() ?? '',
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 16,
                                            ),
                                          ),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      _lines.clear();
                                      _lotsByProduct.clear();
                                      _prepareReturn(distributorId: val);
                                    }
                                  },
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFDDE6F2),
                                    ),
                                  ),
                                  child: Text(
                                    _nameOf(_prepareData?['distributor']),
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              const Text(
                                'Source Location',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFDDE6F2),
                                  ),
                                ),
                                child: Text(
                                  _nameOf(_prepareData?['source_location']),
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Warehouse',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFDDE6F2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _nameOf(_prepareData?['warehouse']),
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Challan Number
                        const Text(
                          'Challan Number',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _challanNumberController,
                          decoration: InputDecoration(
                            hintText: 'Enter challan number',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFDDE6F2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFDDE6F2),
                              ),
                            ),
                          ),
                          enabled: !_isReadOnly,
                        ),
                        const SizedBox(height: 16),
                        // Damage Type
                        const Text(
                          'Damage Type',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedDamageType,
                          items: const [
                            DropdownMenuItem(
                              value: 'non_salable',
                              child: Text('Non Salable'),
                            ),
                            DropdownMenuItem(
                              value: 'quality',
                              child: Text('Quality'),
                            ),
                            DropdownMenuItem(
                              value: 'saleable',
                              child: Text('Saleable'),
                            ),
                          ],
                          onChanged: _isReadOnly
                              ? null
                              : (val) =>
                                    setState(() => _selectedDamageType = val),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFDDE6F2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFDDE6F2),
                              ),
                            ),
                          ),
                          hint: const Text('Select Damage Type'),
                        ),
                        const SizedBox(height: 24),

                        // Return Items Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Return Items',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (!_isReadOnly)
                              TextButton.icon(
                                onPressed: _selectProducts,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Product'),
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFDEE5FC),
                                  foregroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_lines.isEmpty)
                          const EmptyPanel(message: 'No return products added')
                        else
                          ..._lines.map(
                            (line) => _ReturnLineCard(
                              line: line,
                              onRemove: () =>
                                  setState(() => _lines.remove(line)),
                              lots: _lotsByProduct[line.product.id] ?? [],
                              isLoadingLots: _isLoadingLots,
                              onAddLot: () => _addLot(line),
                              onRemoveLot: (lot) =>
                                  setState(() => line.lotLines.remove(lot)),
                              onLotChanged: (lotInput, selectedLot) {
                                setState(() {
                                  lotInput.lot = selectedLot;
                                  if (selectedLot != null) {
                                    final initVal = 1
                                        .clamp(0, selectedLot.availableQty)
                                        .toDouble();
                                    if (canEditSoQty) {
                                      if (lotInput.soQty == null ||
                                          lotInput.soQty! <= 0) {
                                        lotInput.soQty = initVal;
                                      }
                                      lotInput.quantity = 0;
                                    } else if (canEditQcQty) {
                                      if (lotInput.qcQty == null ||
                                          lotInput.qcQty! <= 0) {
                                        lotInput.qcQty = initVal;
                                      }
                                      lotInput.quantity = 0;
                                    } else {
                                      if (lotInput.quantity <= 0) {
                                        lotInput.quantity = initVal;
                                      }
                                    }
                                  }
                                });
                              },
                              onLotMinus: (lotInput) => _changeLotQty(
                                lotInput,
                                lotInput.lot?.availableQty ??
                                    line.product.availableQty,
                                -1,
                              ),
                              onLotPlus: (lotInput) => _changeLotQty(
                                lotInput,
                                lotInput.lot?.availableQty ??
                                    line.product.availableQty,
                                1,
                              ),
                              allocatedQty: canEditSoQty
                                  ? _allocatedSoQty(line)
                                  : (canEditQcQty
                                      ? _allocatedQcQty(line)
                                      : _allocatedQty(line)),
                              isReadOnly: _isReadOnly,
                              canEditSoQty: canEditSoQty,
                              canEditQcQty: canEditQcQty,
                              canEditEffectiveQty: canEditEffectiveQty,
                              onQuantityChanged: (newQty) {
                                setState(() {
                                  final maxQty = line.product.availableQty;
                                  final safeMax = maxQty > 1 ? maxQty : 1.0;
                                  line.quantity = newQty.clamp(1, safeMax);
                                  // trigger rebuild
                                  _allocatedQty(line);
                                });
                              },
                              onSoQtyChanged: (newQty) {
                                setState(() {
                                  line.soQty = newQty;
                                });
                              },
                              onQcQtyChanged: (newQty) {
                                setState(() {
                                  line.qcQty = newQty;
                                });
                              },
                              onLotQtyInput: (lotInput, newLotQty) {
                                setState(() {
                                  final maxQty =
                                      lotInput.lot?.availableQty ??
                                      line.product.availableQty;
                                  final clampedVal = newLotQty
                                      .clamp(0, maxQty)
                                      .toDouble();
                                  if (canEditSoQty) {
                                    lotInput.soQty = clampedVal;
                                  } else if (canEditQcQty) {
                                    lotInput.qcQty = clampedVal;
                                  } else {
                                    lotInput.quantity = clampedVal;
                                  }
                                });
                              },
                            ),
                          ),
                      ],
                    ),
            ),
            // Bottom Bar
            if (!_isReadOnly)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFDDE6F2))),
                ),
                child: widget.returnId == null
                    ? SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: provider.isLoading ? null : _createReturn,
                          icon: const Icon(Icons.inventory),
                          label: const Text('Process Return'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          if (auth.canCancelReturnFor(widget.moduleType)) ...[
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: provider.isLoading
                                    ? null
                                    : () => _runAction('cancel'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                          if (auth.canSaveReturnFor(widget.moduleType)) ...[
                            if (auth.canCancelReturnFor(widget.moduleType))
                              const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: provider.isLoading
                                    ? null
                                    : _createReturn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Save',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                          if (auth.canValidateReturnFor(widget.moduleType)) ...[
                            if (auth.canCancelReturnFor(widget.moduleType) ||
                                auth.canSaveReturnFor(widget.moduleType))
                              const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: provider.isLoading
                                    ? null
                                    : () => _runAction('validate'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Validate',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReturnLineCard extends StatelessWidget {
  const _ReturnLineCard({
    required this.line,
    required this.onRemove,
    required this.lots,
    required this.isLoadingLots,
    required this.onAddLot,
    required this.onRemoveLot,
    required this.onLotChanged,
    required this.onLotMinus,
    required this.onLotPlus,
    required this.allocatedQty,
    this.isReadOnly = false,
    this.canEditSoQty = false,
    this.canEditQcQty = false,
    this.canEditEffectiveQty = false,
    this.onQuantityChanged,
    this.onSoQtyChanged,
    this.onQcQtyChanged,
    this.onLotQtyInput,
  });

  final VirtualTransferLineEntry line;
  final VoidCallback onRemove;
  final List<TransferLot> lots;
  final bool isLoadingLots;
  final VoidCallback onAddLot;
  final ValueChanged<TransferLotInput> onRemoveLot;
  final void Function(TransferLotInput lotInput, TransferLot? selectedLot)
  onLotChanged;
  final ValueChanged<TransferLotInput> onLotMinus;
  final ValueChanged<TransferLotInput> onLotPlus;
  final double allocatedQty;
  final bool isReadOnly;
  final bool canEditSoQty;
  final bool canEditQcQty;
  final bool canEditEffectiveQty;
  final ValueChanged<double>? onQuantityChanged;
  final ValueChanged<double>? onSoQtyChanged;
  final ValueChanged<double>? onQcQtyChanged;
  final void Function(TransferLotInput lotInput, double quantity)?
  onLotQtyInput;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFDEE5FC).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE6F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDEE5FC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${line.product.code ?? '-'}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isReadOnly)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          if (line.product.requiresLots) ...[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LOT DETAILS',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Active Lots: ${line.lotLines.length}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFDDE6F2)),
                  ...line.lotLines.map(
                    (lotInput) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ReturnLotRow(
                        lotInput: lotInput,
                        lots: lots,
                        onChanged: (lot) => onLotChanged(lotInput, lot),
                        onRemove: () => onRemoveLot(lotInput),
                        onMinus: () => onLotMinus(lotInput),
                        onPlus: () => onLotPlus(lotInput),
                        isReadOnly: isReadOnly,
                        onQuantityChanged: onLotQtyInput != null
                            ? (newVal) => onLotQtyInput!(lotInput, newVal)
                            : null,
                        canEditSoQty: canEditSoQty,
                        canEditQcQty: canEditQcQty,
                        canEditEffectiveQty: canEditEffectiveQty,
                      ),
                    ),
                  ),
                  if (!isReadOnly)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isLoadingLots ? null : onAddLot,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(isLoadingLots ? 'Loading...' : 'Add Lot'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: Color(0xFFDDE6F2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (!isReadOnly) const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Return Qty:',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                      Text(
                        '${allocatedQty.toStringAsFixed(0)} ${line.product.uomName}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _buildQtyRow(
                    title: 'Available Qty',
                    value: line.product.availableQty,
                    isReadOnly: true,
                    min: 0,
                    max: line.product.availableQty,
                    onChanged: null,
                  ),
                  _buildQtyRow(
                    title: 'SO Qty',
                    value: line.soQty ?? 0,
                    isReadOnly: isReadOnly || !canEditSoQty,
                    min: 0,
                    max: line.product.availableQty,
                    onChanged: onSoQtyChanged,
                  ),
                  _buildQtyRow(
                    title: 'QC Qty',
                    value: line.qcQty ?? 0,
                    isReadOnly: isReadOnly || !canEditQcQty,
                    min: 0,
                    max: line.product.availableQty,
                    onChanged: onQcQtyChanged,
                  ),
                  _buildQtyRow(
                    title: 'Return Qty',
                    value: line.quantity,
                    isReadOnly: isReadOnly || !canEditEffectiveQty,
                    min: 0,
                    max: line.product.availableQty,
                    onChanged: onQuantityChanged,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQtyRow({
    required String title,
    required double value,
    required bool isReadOnly,
    required double min,
    required double max,
    required ValueChanged<double>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const Spacer(),
          if (isReadOnly)
            Text(
              value.toStringAsFixed(0),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            )
          else
            SmallStepper(
              value: value.toStringAsFixed(0),
              onMinus: () {
                if (value > min) {
                  onChanged?.call(value - 1);
                }
              },
              onPlus: () {
                if (value < max) {
                  onChanged?.call(value + 1);
                }
              },
              onValueInput: (val) {
                final parsed = double.tryParse(val);
                if (parsed != null) {
                  final safeMax = max > min ? max : min;
                  onChanged?.call(parsed.clamp(min, safeMax));
                }
              },
            ),
        ],
      ),
    );
  }
}

class _ReturnLotRow extends StatelessWidget {
  const _ReturnLotRow({
    required this.lotInput,
    required this.lots,
    required this.onChanged,
    required this.onRemove,
    required this.onMinus,
    required this.onPlus,
    this.isReadOnly = false,
    this.onQuantityChanged,
    required this.canEditSoQty,
    required this.canEditQcQty,
    required this.canEditEffectiveQty,
  });

  final TransferLotInput lotInput;
  final List<TransferLot> lots;
  final ValueChanged<TransferLot?> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool isReadOnly;
  final ValueChanged<double>? onQuantityChanged;
  final bool canEditSoQty;
  final bool canEditQcQty;
  final bool canEditEffectiveQty;

  @override
  Widget build(BuildContext context) {
    double activeQty = lotInput.quantity;
    String label = 'Return Qty';
    if (canEditSoQty) {
      activeQty = lotInput.soQty ?? lotInput.quantity;
      label = 'SO Qty';
    } else if (canEditQcQty) {
      activeQty = lotInput.qcQty ?? lotInput.quantity;
      label = 'QC Qty';
    } else {
      activeQty = lotInput.quantity;
      label = 'Return Qty';
    }

    final displayLots = List<TransferLot>.from(lots);
    if (lotInput.lot != null &&
        !displayLots.any((l) => l.lotId == lotInput.lot!.lotId)) {
      displayLots.add(lotInput.lot!);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lot Reference',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  if (lotInput.lot != null)
                    Text(
                      'Avail: ${lotInput.lot!.availableQty.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              if ((lotInput.soQty != null && lotInput.soQty! > 0) ||
                  (lotInput.qcQty != null && lotInput.qcQty! > 0)) ...[
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    if (lotInput.soQty != null && lotInput.soQty! > 0)
                      Text(
                        'SO Qty: ${lotInput.soQty!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    if (lotInput.qcQty != null && lotInput.qcQty! > 0)
                      Text(
                        'QC Qty: ${lotInput.qcQty!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: lotInput.lot?.lotId,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFDDE6F2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFDDE6F2)),
                  ),
                ),
                items: displayLots
                    .map(
                      (lot) => DropdownMenuItem(
                        value: lot.lotId,
                        child: Text(
                          "${lot.lotName} (Avail: ${lot.availableQty.toStringAsFixed(0)})",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isReadOnly
                    ? null
                    : (val) {
                        TransferLot? selected;
                        for (final lot in displayLots) {
                          if (lot.lotId == val) {
                            selected = lot;
                            break;
                          }
                        }
                        onChanged(selected);
                      },
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: const Color(0xFFDDE6F2)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 32,
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        enabled: !isReadOnly && onQuantityChanged != null,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && onQuantityChanged != null) {
                            onQuantityChanged!(parsed);
                          }
                        },
                        controller:
                            TextEditingController(
                                text: activeQty.toStringAsFixed(0),
                              )
                              ..selection = TextSelection.collapsed(
                                offset: activeQty.toStringAsFixed(0).length,
                              ),
                      ),
                    ),
                    if (!isReadOnly)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: onMinus,
                            child: const Icon(
                              Icons.remove,
                              size: 16,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: onPlus,
                            child: const Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.black54,
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
        if (!isReadOnly) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: onRemove,
          ),
        ],
      ],
    );
  }
}
