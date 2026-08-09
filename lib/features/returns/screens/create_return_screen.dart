import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:secondary_sales/core/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/features/returns/return_provider.dart';
import 'package:secondary_sales/features/returns/screens/return_product_selection_screen.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/widgets/stock_excess_dialog.dart';

class CreateReturnScreen extends StatefulWidget {
  final int? returnId;
  final String moduleType;
  final String title;
  final String productSelectionTitle;
  final String endpoint;

  const CreateReturnScreen({
    super.key,
    this.returnId,
    this.moduleType = 'primary',
    this.title = 'Returns',
    this.productSelectionTitle = 'Select Return Products',
    this.endpoint = AppConstants.returnsEndpoint,
  });

  @override
  State<CreateReturnScreen> createState() => _CreateReturnScreenState();
}

class _CreateReturnScreenState extends State<CreateReturnScreen> {
  bool get _allowsPrimaryOverstock =>
      widget.moduleType.toLowerCase() == 'primary' || widget.moduleType.isEmpty;

  final List<VirtualTransferLineEntry> _lines = [];
  final Map<int, List<TransferLot>> _lotsByProduct = {};
  bool _isLoadingLots = false;
  Map<String, dynamic>? _prepareData;
  bool _isPreparing = true;
  bool _isReadOnly = false;

  final TextEditingController _challanNumberController =
      TextEditingController();
  String? _selectedDamageType = 'saleable';

  File? _challanImageFile;
  String? _challanImageBase64;
  String? _challanImageName;

  Future<void> _pickChallanImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      setState(() {
        _challanImageFile = file;
        _challanImageBase64 = base64Str;
        _challanImageName = picked.name.isNotEmpty
            ? picked.name
            : 'return_challan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

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
        endpoint: widget.endpoint,
      );
      if (!mounted) return;
      if (details == null) {
        setState(() {
          _isPreparing = false;
        });
        return;
      }
      setState(() {
        _lines.clear();
        _isReadOnly =
            details['state'] == 'done' || details['state'] == 'cancel';
        _challanNumberController.text = details['challan_number'] ?? '';
        _selectedDamageType = details['damage_type'] ?? 'saleable';
        _prepareData = {
          'distributor': details['distributor'],
          'source_location': details['source_location'],
          'warehouse': details['destination_location'],
          'return_book_number': details['return_book_number'],
          'return_book_page': details['return_book_page'],
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
            qcQty: ((ld['warehouse_qty'] ?? ld['qc_qty']) as num?)?.toDouble(),
          );

          final lotLinesData = ld['lot_lines'] as List<dynamic>? ?? [];
          for (final ll in lotLinesData) {
            final lotData = ll['lot'];
            if (lotData != null) {
              final lotId = lotData['id'] as int;
              final lotName = lotData['name'] as String;
              final lotQty = (ll['quantity'] as num?)?.toDouble() ?? 0.0;
              final soQty = (ll['so_qty'] as num?)?.toDouble();
              final qcQty = ((ll['warehouse_qty'] ?? ll['qc_qty']) as num?)?.toDouble() ?? lotQty;
              final lotAvail =
                  (lotData['available_qty'] as num?)?.toDouble() ?? lotQty;

              final maxCurrent = [
                lotQty,
                soQty ?? 0.0,
                qcQty,
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
    } else {
      setState(() {
        _isPreparing = true;
      });
      final data = await provider.prepareReturn(
        distributorId: distributorId,
        endpoint: widget.endpoint,
      );
      if (mounted && data != null) {
        setState(() {
          _prepareData = data;
        });

        final resolvedDistributorId = data['distributor']?['id'] as int?;
        if (resolvedDistributorId != null) {
          final products = await provider.fetchReturnProducts(
            distributorId: resolvedDistributorId,
            endpoint: widget.endpoint,
          );
          if (mounted) {
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
                      qcQty: auth.canEditWarehouseQty ? product.availableQty : null,
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
          title: widget.productSelectionTitle,
          endpoint: widget.endpoint,
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
        endpoint: widget.endpoint,
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
        lotInput.soQty = next.clamp(0, double.infinity).toDouble();
      } else if (auth.canEditWarehouseQty) {
        final current = lotInput.qcQty ?? lotInput.quantity;
        final next = current + delta;
        lotInput.qcQty = next.clamp(0, double.infinity).toDouble();
      } else {
        final next = lotInput.quantity + delta;
        lotInput.quantity = next.clamp(0, double.infinity).toDouble();
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

  void _syncSingleLotFromLine(VirtualTransferLineEntry line) {
    if (!_allowsPrimaryOverstock || line.product.tracking == 'none') {
      return;
    }
    if (line.lotLines.length != 1) {
      return;
    }
    final lotInput = line.lotLines.first;
    lotInput.quantity = line.quantity;
    if (line.soQty != null) {
      lotInput.soQty = line.soQty;
    }
    if (line.qcQty != null) {
      lotInput.qcQty = line.qcQty;
    }
  }

  double _submittedTrackedLotQty(TransferLotInput lotInput, AuthProvider auth) {
    if (_allowsPrimaryOverstock && auth.canEditSoQty) {
      return lotInput.soQty ?? lotInput.quantity;
    }
    if (_allowsPrimaryOverstock && auth.canEditWarehouseQty) {
      return lotInput.qcQty ?? lotInput.quantity;
    }
    return lotInput.quantity;
  }

  double _submittedTrackedLineQty(VirtualTransferLineEntry line, AuthProvider auth) {
    return line.lotLines.fold<double>(0, (sum, lot) {
      if (lot.lot == null) {
        return sum;
      }
      return sum + _submittedTrackedLotQty(lot, auth);
    });
  }

  double _submittedTrackedSoQty(VirtualTransferLineEntry line) {
    return line.lotLines.fold<double>(0, (sum, lot) {
      if (lot.lot == null) {
        return sum;
      }
      return sum + (lot.soQty ?? lot.quantity);
    });
  }

  double _submittedTrackedQcQty(VirtualTransferLineEntry line) {
    return line.lotLines.fold<double>(0, (sum, lot) {
      if (lot.lot == null) {
        return sum;
      }
      return sum + (lot.qcQty ?? lot.quantity);
    });
  }

  bool _lineHasSubmittedQty(VirtualTransferLineEntry line, AuthProvider auth) {
    final qty = line.product.tracking != 'none'
        ? _submittedTrackedLineQty(line, auth)
        : line.quantity;
    final soQty = line.product.tracking != 'none'
        ? _submittedTrackedSoQty(line)
        : line.soQty;
    final qcQty = line.product.tracking != 'none'
        ? _submittedTrackedQcQty(line)
        : line.qcQty;

    return qty > 0 || (soQty ?? 0.0) > 0 || (qcQty ?? 0.0) > 0;
  }

  List<Map<String, dynamic>> _buildLinesPayload(AuthProvider auth) {
    return _lines.where((line) => _lineHasSubmittedQty(line, auth)).map((line) {
      final selectedLots = line.lotLines.where((l) => l.lot != null).toList();
      final qty = line.product.tracking != 'none'
          ? _submittedTrackedLineQty(line, auth)
          : line.quantity;
      final soQty = line.product.tracking != 'none'
          ? _submittedTrackedSoQty(line)
          : line.soQty;
      final qcQty = line.product.tracking != 'none'
          ? _submittedTrackedQcQty(line)
          : line.qcQty;

      return {
        'product_id': line.product.id,
        'product_uom_qty': 0.0,
        'quantity': qty,
        if (soQty != null && soQty > 0) 'so_qty': soQty,
        if (qcQty != null && qcQty > 0) 'warehouse_qty': qcQty,
        'lot_lines': selectedLots
            .map(
              (l) => {
                'lot_id': l.lot!.lotId,
                'product_uom_qty': 0.0,
                'quantity': _submittedTrackedLotQty(l, auth),
                if (l.soQty != null && l.soQty! > 0) 'so_qty': l.soQty,
                if (l.qcQty != null && l.qcQty! > 0) 'warehouse_qty': l.qcQty,
              },
            )
            .toList(),
      };
    }).toList();
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

    if (!_allowsPrimaryOverstock) {
      final excessItems = <StockExcessItem>[];
      for (final line in _lines) {
        if (line.quantity > line.product.availableQty) {
          excessItems.add(StockExcessItem(
            productName: line.product.name,
            enteredQty: line.quantity,
            availableQty: line.product.availableQty,
          ));
        }
      }
      if (excessItems.isNotEmpty) {
        await showStockExcessValidationDialog(context, excessItems: excessItems);
        return;
      }
    }

    final auth = context.read<AuthProvider>();
    final linesData = _buildLinesPayload(auth);
    if (linesData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product')),
      );
      return;
    }

    // Mandatory Photo Evidence Validation for Primary Sales Return
    if ((widget.moduleType.toLowerCase() == 'primary' || widget.moduleType.isEmpty) &&
        widget.returnId == null) {
      if (_challanImageBase64 == null || _challanImageBase64!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return Challan Photo Evidence is required for Primary Sales Return.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    Map<String, dynamic>? result;
    if (widget.returnId != null) {
      result = await context.read<ReturnProvider>().updateReturnDelivery(
        widget.returnId!,
        lines: linesData,
        type: widget.moduleType,
        challanNumber: _challanNumberController.text,
        damageType: _selectedDamageType,
        endpoint: widget.endpoint,
      );
    } else {
      result = await context.read<ReturnProvider>().createReturnDelivery(
        lines: linesData,
        distributorId: distributorId,
        type: widget.moduleType,
        challanNumber: _challanNumberController.text,
        damageType: _selectedDamageType,
        attachmentBase64: _challanImageBase64,
        attachmentFilename: _challanImageName,
        endpoint: widget.endpoint,
      );
    }

    if (!mounted) return;
    if (result == null) {
      final error = context.read<ReturnProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to create ${widget.title.toLowerCase()}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.title} created successfully!'),
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
        final auth = context.read<AuthProvider>();
        final linesData = _buildLinesPayload(auth);

        final saveRes = await context
            .read<ReturnProvider>()
            .updateReturnDelivery(
              widget.returnId!,
              lines: linesData,
              type: widget.moduleType,
              challanNumber: _challanNumberController.text,
              damageType: _selectedDamageType,
              endpoint: widget.endpoint,
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
        type: widget.moduleType,
        endpoint: widget.endpoint,
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
              '${widget.title} ${action == 'validate' ? 'validated' : 'cancelled'} successfully',
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
    final canEditWarehouseQty = auth.canEditWarehouseQty;
    final canEditEffectiveQty = auth.canEditEffectiveQty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.title,
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
                              if (widget.moduleType.toLowerCase() == 'primary' || widget.moduleType.isEmpty) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Return Book & Page (Auto-Assigned)',
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
                                    color: const Color(0xFFF0F4F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFDDE6F2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.menu_book,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _prepareData?['return_book_number'] != null || _prepareData?['return_book_page'] != null
                                              ? '${_prepareData?['return_book_number'] ?? '-'} (Page ${_prepareData?['return_book_page'] ?? '-'})'
                                              : (_prepareData?['next_return_book_number'] != null || _prepareData?['next_return_book_page'] != null
                                                  ? '${_prepareData?['next_return_book_number'] ?? '-'} (Page ${_prepareData?['next_return_book_page'] ?? '-'})'
                                                  : 'No active Return Book assigned'),
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                              value: 'saleable',
                              child: Text('Saleable'),
                            ),
                          ],
                          onChanged: null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.primarySoft,
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
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFDDE6F2),
                              ),
                            ),
                          ),
                        ),
                        if (widget.moduleType.toLowerCase() == 'primary' ||
                            widget.moduleType.isEmpty) ...[
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Text(
                                'Return Challan Photo Evidence',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' *',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _challanImageFile == null
                                    ? const Color(0xFFDDE6F2)
                                    : AppColors.primary,
                                width: _challanImageFile == null ? 1 : 1.5,
                              ),
                            ),
                            child: _challanImageFile == null
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _isReadOnly
                                              ? null
                                              : () => _pickChallanImage(
                                                    ImageSource.camera,
                                                  ),
                                          icon: const Icon(
                                            Icons.camera_alt_outlined,
                                            size: 18,
                                          ),
                                          label: const Text('Camera'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            side: const BorderSide(
                                              color: AppColors.primary,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _isReadOnly
                                              ? null
                                              : () => _pickChallanImage(
                                                    ImageSource.gallery,
                                                  ),
                                          icon: const Icon(
                                            Icons.photo_library_outlined,
                                            size: 18,
                                          ),
                                          label: const Text('Gallery'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            side: const BorderSide(
                                              color: AppColors.primary,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.file(
                                          _challanImageFile!,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _challanImageName ?? 'Photo Attached',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!_isReadOnly)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _challanImageFile = null;
                                              _challanImageBase64 = null;
                                              _challanImageName = null;
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                          ),
                        ],
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
                                    final initVal = 1.0;
                                    if (canEditSoQty) {
                                      if (lotInput.soQty == null ||
                                          lotInput.soQty! <= 0) {
                                        lotInput.soQty = initVal;
                                      }
                                      lotInput.quantity = 0;
                                    } else if (canEditWarehouseQty) {
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
                                double.infinity,
                                -1,
                              ),
                              onLotPlus: (lotInput) => _changeLotQty(
                                lotInput,
                                double.infinity,
                                1,
                              ),
                              allocatedQty: canEditSoQty
                                  ? _allocatedSoQty(line)
                                  : (canEditWarehouseQty
                                      ? _allocatedQcQty(line)
                                      : _allocatedQty(line)),
                              isReadOnly: _isReadOnly,
                              canEditSoQty: canEditSoQty,
                              canEditWarehouseQty: canEditWarehouseQty,
                              canEditEffectiveQty: canEditEffectiveQty,
                              allowOverstock: _allowsPrimaryOverstock,
                              onQuantityChanged: (newQty) {
                                setState(() {
                                  line.quantity = (_allowsPrimaryOverstock
                                          ? newQty.clamp(0, double.infinity)
                                          : newQty.clamp(0, line.product.availableQty))
                                      .toDouble();
                                  _syncSingleLotFromLine(line);
                                  // trigger rebuild
                                  _allocatedQty(line);
                                });
                              },
                              onSoQtyChanged: (newQty) {
                                setState(() {
                                  line.soQty = (_allowsPrimaryOverstock
                                          ? newQty.clamp(0, double.infinity)
                                          : newQty.clamp(0, line.product.availableQty))
                                      .toDouble();
                                  if (_allowsPrimaryOverstock) {
                                    line.quantity = line.soQty ?? line.quantity;
                                  }
                                  _syncSingleLotFromLine(line);
                                });
                              },
                              onQcQtyChanged: (newQty) {
                                setState(() {
                                  line.qcQty = (_allowsPrimaryOverstock
                                          ? newQty.clamp(0, double.infinity)
                                          : newQty.clamp(0, line.product.availableQty))
                                      .toDouble();
                                  if (_allowsPrimaryOverstock) {
                                    line.quantity = line.qcQty ?? line.quantity;
                                  }
                                  _syncSingleLotFromLine(line);
                                });
                              },
                              onLotQtyInput: (lotInput, newLotQty) {
                                setState(() {
                                  final enteredVal = newLotQty
                                      .clamp(0, double.infinity)
                                      .toDouble();
                                  if (canEditSoQty) {
                                    lotInput.soQty = enteredVal;
                                  } else if (canEditWarehouseQty) {
                                    lotInput.qcQty = enteredVal;
                                  } else {
                                    lotInput.quantity = enteredVal;
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
    this.canEditWarehouseQty = false,
    this.canEditEffectiveQty = false,
    this.allowOverstock = false,
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
  final bool canEditWarehouseQty;
  final bool canEditEffectiveQty;
  final bool allowOverstock;
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
                        canEditWarehouseQty: canEditWarehouseQty,
                        canEditEffectiveQty: canEditEffectiveQty,
                      ),
                    ),
                  ),
                  if (!isReadOnly) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Qty:',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                        Text(
                          '${line.product.availableQty.toStringAsFixed(0)} ${line.product.uomName}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                  ],
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
                    max: allowOverstock ? double.infinity : line.product.availableQty,
                    onChanged: onSoQtyChanged,
                  ),
                  if (canEditWarehouseQty)
                    _buildQtyRow(
                      title: 'Warehouse Qty',
                      value: line.qcQty ?? 0,
                      isReadOnly: isReadOnly,
                      min: 0,
                      max: allowOverstock ? double.infinity : line.product.availableQty,
                      onChanged: onQcQtyChanged,
                    ),
                  if (canEditEffectiveQty)
                    _buildQtyRow(
                      title: 'QC Qty (Effective)',
                      value: line.quantity,
                      isReadOnly: isReadOnly,
                      min: 0,
                      max: allowOverstock ? double.infinity : line.product.availableQty,
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
    required this.canEditWarehouseQty,
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
  final bool canEditWarehouseQty;
  final bool canEditEffectiveQty;

  @override
  Widget build(BuildContext context) {
    double activeQty = lotInput.quantity;
    String label = 'Return Qty';
    if (canEditSoQty) {
      activeQty = lotInput.soQty ?? lotInput.quantity;
      label = 'SO Qty';
    } else if (canEditWarehouseQty) {
      activeQty = lotInput.qcQty ?? lotInput.quantity;
      label = 'Warehouse Qty';
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
                        'Warehouse Qty: ${lotInput.qcQty!.toStringAsFixed(0)}',
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
                          lot.lotName,
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
