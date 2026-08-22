import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:secondary_sales/core/util/parse.dart';
import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/scraps/scrap_provider.dart';
import 'package:secondary_sales/features/scraps/screens/scrap_product_selection_screen.dart';

import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/widgets/stock_excess_dialog.dart';

class CreateScrapScreen extends StatefulWidget {
  final int? scrapId;
  final String moduleType;
  final String title;
  final String productSelectionTitle;

  const CreateScrapScreen({
    super.key,
    this.scrapId,
    this.moduleType = 'primary',
    this.title = 'Scraps',
    this.productSelectionTitle = 'Select Scrap Products',
  });

  @override
  State<CreateScrapScreen> createState() => _CreateScrapScreenState();
}

class _CreateScrapScreenState extends State<CreateScrapScreen> {
  bool get _allowsPrimaryOverstock =>
      widget.moduleType.toLowerCase() == 'primary' || widget.moduleType.isEmpty;

  final List<VirtualTransferLineEntry> _lines = [];
  final Map<int, List<TransferLot>> _lotsByProduct = {};
  bool _isLoadingLots = false;
  Map<String, dynamic>? _prepareData;
  bool _isPreparing = true;

  /// Whether this picking carries the scrap QC decision, i.e. the backend
  /// reported `qc_mode == 'scrap_sum'`.
  ///
  /// Served rather than derived here. When set, the movement quantity is
  /// `actual_qc_qty + qc_nonsaleable_qty` and the app stops sending `quantity`
  /// at all. Nothing on a damaged or quality return is saleable, so it carries
  /// its own warehouse and QC columns instead of the fresh ones.
  bool _scrapSum = false;
  bool _isReadOnly = false;
  String? _selectedDamageType;

  File? _challanImageFile;
  String? _challanImageBase64;
  String? _challanImageName;
  String? _serverImageUrl;

  void _showFullscreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(
                  imageUrl,
                  headers: context.read<AuthProvider>().authHeaders,
                  fit: BoxFit.contain,
                  errorBuilder: (context, err, st) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            : 'return_scrap_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick photo: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareScrap();
    });
  }

  Future<void> _prepareScrap({int? distributorId}) async {
    final provider = context.read<ScrapProvider>();

    if (widget.scrapId != null) {
      final details = await provider.getScrapDetails(
        widget.scrapId!,
        type: widget.moduleType,
      );
      if (!mounted) return;
      if (details == null) {
        setState(() {
          _isPreparing = false;
        });
        return;
      }
      {
        setState(() {
          _isReadOnly =
              details['state'] == 'done' || details['state'] == 'cancel';
          _scrapSum = details['qc_mode'] == 'scrap_sum';
          _selectedDamageType = details['damage_type'];
          final atts = details['attachments'] as List<dynamic>?;
          if (atts != null && atts.isNotEmpty) {
            final first = atts.firstWhere(
              (a) => a['is_image'] == true,
              orElse: () => atts.first,
            );
            if (first != null && first['url'] != null) {
              final rawUrl = first['url'].toString();
              _serverImageUrl = rawUrl.startsWith('http')
                  ? rawUrl
                  : '${AppConstants.baseUrl}$rawUrl';
            }
          }
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
              qcQty: ((ld['warehouse_qty'] ?? ld['qc_qty']) as num?)
                  ?.toDouble(),
              wNonsaleableQty: (ld['w_nonsaleable_qty'] as num?)?.toDouble(),
              wQcQty: (ld['w_qc_qty'] as num?)?.toDouble(),
              actualQcQty: (ld['actual_qc_qty'] as num?)?.toDouble(),
              qcNonsaleableQty: (ld['qc_nonsaleable_qty'] as num?)?.toDouble(),
            );

            final lotLinesData = ld['lot_lines'] as List<dynamic>? ?? [];
            for (final ll in lotLinesData) {
              final lotData = ll['lot'];
              if (lotData != null) {
                final lotId = lotData['id'] as int;
                final lotName = lotData['name'] as String;
                final lotQty = (ll['quantity'] as num?)?.toDouble() ?? 0.0;
                final soQty = (ll['so_qty'] as num?)?.toDouble();
                final qcQty =
                    ((ll['warehouse_qty'] ?? ll['qc_qty']) as num?)
                        ?.toDouble() ??
                    lotQty;
                final wNonsaleableQty = (ll['w_nonsaleable_qty'] as num?)
                    ?.toDouble();
                final wQcQty = (ll['w_qc_qty'] as num?)?.toDouble();
                final actualQcQty = (ll['actual_qc_qty'] as num?)?.toDouble();
                final qcNonsaleableQty = (ll['qc_nonsaleable_qty'] as num?)
                    ?.toDouble();
                final lotAvail =
                    (lotData['available_qty'] as num?)?.toDouble() ?? lotQty;

                // Never clamp the stepper below a value already recorded
                // against this lot, whichever column it sits in.
                final maxCurrent = [
                  lotQty,
                  soQty ?? 0.0,
                  qcQty,
                  wNonsaleableQty ?? 0.0,
                  wQcQty ?? 0.0,
                  actualQcQty ?? 0.0,
                  qcNonsaleableQty ?? 0.0,
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
                    ..qcQty = qcQty
                    ..wNonsaleableQty = wNonsaleableQty
                    ..wQcQty = wQcQty
                    ..actualQcQty = actualQcQty
                    ..qcNonsaleableQty = qcNonsaleableQty,
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
      final data = await provider.prepareScrap(distributorId: distributorId);
      if (!mounted) return;
      if (data == null) {
        // Clearing the flag is what lets the ErrorPanel render provider.error.
        // Left set, the screen spins forever and the backend's message is lost.
        setState(() {
          _isPreparing = false;
        });
        return;
      }
      {
        setState(() {
          _prepareData = data;
        });

        final resolvedDistributorId = data['distributor']?['id'] as int?;
        if (resolvedDistributorId != null) {
          final products = await provider.getScrapProducts(
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
                      qcQty: auth.canEditWarehouseQty
                          ? product.availableQty
                          : null,
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
        builder: (_) => ScrapProductSelectionScreen(
          distributorId: distributorId,
          initialLines: _lines,
          title: widget.productSelectionTitle,
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
      final res = await context.read<ScrapProvider>().getScrapProductLots(
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

  void _setLotQty(TransferLotInput lotInput, double newQty) {
    final auth = context.read<AuthProvider>();
    setState(() {
      if (auth.canEditSoQty) {
        lotInput.soQty = newQty.clamp(0, double.infinity).toDouble();
      } else if (auth.canEditWarehouseQty) {
        lotInput.qcQty = newQty.clamp(0, double.infinity).toDouble();
      } else {
        lotInput.quantity = newQty.clamp(0, double.infinity).toDouble();
      }
    });
  }

  double _allocatedQty(VirtualTransferLineEntry line) {
    return line.lotLines.fold<double>(0, (sum, lot) => sum + lot.quantity);
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

  double _submittedTrackedLineQty(
    VirtualTransferLineEntry line,
    AuthProvider auth,
  ) {
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

  /// Sum one per-lot column across the lots actually chosen on this line.
  double _lotSum(
    VirtualTransferLineEntry line,
    double? Function(TransferLotInput) pick,
  ) {
    return line.lotLines
        .where((l) => l.lot != null)
        .fold<double>(0, (sum, l) => sum + (pick(l) ?? 0));
  }

  /// The four record-keeping quantities for one line, as the API expects them.
  ///
  /// For tracked products the line totals are summed from the lots, because the
  /// backend rejects any allocation whose lot-wise figures do not match their
  /// line totals.
  Map<String, double> _scrapSumLineValues(VirtualTransferLineEntry line) {
    final tracked = line.product.tracking != 'none';
    return {
      'w_qc_qty': tracked
          ? _lotSum(line, (l) => l.wQcQty)
          : (line.wQcQty ?? 0.0),
      'w_nonsaleable_qty': tracked
          ? _lotSum(line, (l) => l.wNonsaleableQty)
          : (line.wNonsaleableQty ?? 0.0),
      'actual_qc_qty': tracked
          ? _lotSum(line, (l) => l.actualQcQty)
          : (line.actualQcQty ?? 0.0),
      'qc_nonsaleable_qty': tracked
          ? _lotSum(line, (l) => l.qcNonsaleableQty)
          : (line.qcNonsaleableQty ?? 0.0),
    };
  }

  bool _lineHasSubmittedQty(VirtualTransferLineEntry line, AuthProvider auth) {
    if (_scrapSum) {
      // Any of the four counts, plus the SO quantity the line arrived with.
      // The coordinator saves before sales operation has decided anything, and
      // `update_delivery` rebuilds the transfer's moves from this payload -- so
      // dropping a line here would delete it outright.
      final values = _scrapSumLineValues(line);
      return values.values.any((value) => value > 0) || (line.soQty ?? 0) > 0;
    }

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

      if (_scrapSum) {
        // `quantity` is deliberately absent: the backend derives the movement
        // from actual_qc_qty + qc_nonsaleable_qty, so anything sent here would
        // be ignored and would only imply the app still decides what moves.
        return {
          'product_id': line.product.id,
          if (soQty != null && soQty > 0) 'so_qty': soQty,
          ..._scrapSumLineValues(line),
          'lot_lines': selectedLots
              .map(
                (l) => {
                  'lot_id': l.lot!.lotId,
                  if (l.soQty != null && l.soQty! > 0) 'so_qty': l.soQty,
                  'w_qc_qty': l.wQcQty ?? 0.0,
                  'w_nonsaleable_qty': l.wNonsaleableQty ?? 0.0,
                  'actual_qc_qty': l.actualQcQty ?? 0.0,
                  'qc_nonsaleable_qty': l.qcNonsaleableQty ?? 0.0,
                },
              )
              .toList(),
        };
      }

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

  Future<void> _createScrap({bool sendToSalesOperation = false}) async {
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
          excessItems.add(
            StockExcessItem(
              productName: line.product.name,
              enteredQty: line.quantity,
              availableQty: line.product.availableQty,
            ),
          );
        }
      }
      if (excessItems.isNotEmpty) {
        await showStockExcessValidationDialog(
          context,
          excessItems: excessItems,
        );
        return;
      }
    }

    final auth = context.read<AuthProvider>();
    final linesData = _buildLinesPayload(auth);
    if (linesData.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add at least one product')));
      return;
    }

    // Mandatory Photo Evidence Validation for Primary Sales Scrap
    if ((widget.moduleType.toLowerCase() == 'primary' ||
            widget.moduleType.isEmpty) &&
        widget.scrapId == null) {
      if (_challanImageBase64 == null || _challanImageBase64!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Return Challan Photo Evidence is required for Primary Sales Scrap.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    Map<String, dynamic>? result;
    if (widget.scrapId != null) {
      result = await context.read<ScrapProvider>().updateScrapDelivery(
        widget.scrapId!,
        lines: linesData,
        type: widget.moduleType,
        damageType: _selectedDamageType,
        sendToSalesOperation: sendToSalesOperation,
      );
    } else {
      result = await context.read<ScrapProvider>().createScrapDelivery(
        lines: linesData,
        distributorId: distributorId,
        type: widget.moduleType,
        damageType: _selectedDamageType,
        attachmentBase64: _challanImageBase64,
        attachmentFilename: _challanImageName,
      );
    }

    if (!mounted) return;
    if (result == null) {
      final error = context.read<ScrapProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Failed to create ${widget.title.toLowerCase()}',
          ),
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
    if (widget.scrapId == null) return;

    setState(() => _isPreparing = true);

    try {
      if (action == 'validate') {
        // Save first!
        final auth = context.read<AuthProvider>();
        final linesData = _buildLinesPayload(auth);

        final saveRes = await context.read<ScrapProvider>().updateScrapDelivery(
          widget.scrapId!,
          lines: linesData,
          type: widget.moduleType,
          damageType: _selectedDamageType,
        );
        if (saveRes == null) {
          final err =
              context.read<ScrapProvider>().error ??
              'Save failed before validation';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
          return;
        }
      }

      final res = await context.read<ScrapProvider>().executeScrapAction(
        widget.scrapId!,
        action,
        type: widget.moduleType,
      );
      if (!mounted) return;

      if (res == null) {
        final err = context.read<ScrapProvider>().error ?? 'Action failed';
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
    return formatLocationName(value);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScrapProvider>();
    final auth = context.watch<AuthProvider>();
    final canEditSoQty = auth.canEditSoQty;
    final canEditWarehouseQty = auth.canEditWarehouseQty;
    final canEditEffectiveQty = auth.canEditEffectiveQty;
    final canEditQcQty = auth.canEditQcQty;

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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ProfileAvatar(),
          ),
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
                                      _prepareScrap(distributorId: val);
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
                              if (widget.moduleType.toLowerCase() ==
                                      'primary' ||
                                  widget.moduleType.isEmpty) ...[
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
                                          _prepareData?['return_book_number'] !=
                                                      null ||
                                                  _prepareData?['return_book_page'] !=
                                                      null
                                              ? '${_prepareData?['return_book_number'] ?? '-'} (Page ${_prepareData?['return_book_page'] ?? '-'})'
                                              : (_prepareData?['next_return_book_number'] !=
                                                            null ||
                                                        _prepareData?['next_return_book_page'] !=
                                                            null
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
                                color: _challanImageFile == null &&
                                        _serverImageUrl == null
                                    ? const Color(0xFFDDE6F2)
                                    : AppColors.primary,
                                width: (_challanImageFile == null &&
                                        _serverImageUrl == null)
                                    ? 1
                                    : 1.5,
                              ),
                            ),
                            child: _challanImageFile == null &&
                                    _serverImageUrl == null
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
                                      GestureDetector(
                                        onTap: () {
                                          final url = _serverImageUrl;
                                          if (_challanImageFile == null &&
                                              url != null) {
                                            _showFullscreenImage(
                                              context,
                                              url,
                                            );
                                          }
                                        },
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: _challanImageFile != null
                                              ? Image.file(
                                                  _challanImageFile!,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.network(
                                                  _serverImageUrl!,
                                                  headers: context
                                                      .read<AuthProvider>()
                                                      .authHeaders,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (
                                                    context,
                                                    err,
                                                    st,
                                                  ) => Container(
                                                    width: 50,
                                                    height: 50,
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _challanImageFile != null
                                                  ? (_challanImageName ??
                                                        'Photo Attached')
                                                  : 'Uploaded Evidence Photo',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (_challanImageFile == null)
                                              const Text(
                                                'Tap image to view full photo',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (!_isReadOnly &&
                                          _challanImageFile != null)
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

                        // Scrap Items Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Scrap Items',
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
                            (line) => _ScrapLineCard(
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
                              onLotMinus: (lotInput) =>
                                  _changeLotQty(lotInput, double.infinity, -1),
                              onLotPlus: (lotInput) =>
                                  _changeLotQty(lotInput, double.infinity, 1),
                              onLotQtyInput: (lotInput, newQty) =>
                                  _setLotQty(lotInput, newQty),
                              allocatedQty: _allocatedQty(line),
                              isReadOnly: _isReadOnly,
                              canEditSoQty: canEditSoQty,
                              canEditWarehouseQty: canEditWarehouseQty,
                              canEditEffectiveQty: canEditEffectiveQty,
                              canEditQcQty: canEditQcQty,
                              scrapSum: _scrapSum,
                              allowOverstock: _allowsPrimaryOverstock,
                              onWQcQtyChanged: (newQty) {
                                setState(() {
                                  line.wQcQty = newQty
                                      .clamp(0, double.infinity)
                                      .toDouble();
                                  _syncSingleLotFromLine(line);
                                });
                              },
                              onWNonsaleableQtyChanged: (newQty) {
                                setState(() {
                                  line.wNonsaleableQty = newQty
                                      .clamp(0, double.infinity)
                                      .toDouble();
                                  _syncSingleLotFromLine(line);
                                });
                              },
                              onActualQcQtyChanged: (newQty) {
                                setState(() {
                                  line.actualQcQty = newQty
                                      .clamp(0, double.infinity)
                                      .toDouble();
                                  _syncSingleLotFromLine(line);
                                });
                              },
                              onQcNonsaleableQtyChanged: (newQty) {
                                setState(() {
                                  line.qcNonsaleableQty = newQty
                                      .clamp(0, double.infinity)
                                      .toDouble();
                                  _syncSingleLotFromLine(line);
                                });
                              },
                              onLotFieldChanged: (lotInput, field, value) {
                                setState(() {
                                  final v = value
                                      .clamp(0, double.infinity)
                                      .toDouble();
                                  switch (field) {
                                    case 'w_qc_qty':
                                      lotInput.wQcQty = v;
                                      break;
                                    case 'w_nonsaleable_qty':
                                      lotInput.wNonsaleableQty = v;
                                      break;
                                    case 'actual_qc_qty':
                                      lotInput.actualQcQty = v;
                                      break;
                                    case 'qc_nonsaleable_qty':
                                      lotInput.qcNonsaleableQty = v;
                                      break;
                                  }
                                });
                              },
                              onSoQtyChanged: (newQty) {
                                setState(() {
                                  line.soQty =
                                      (_allowsPrimaryOverstock
                                              ? newQty.clamp(0, double.infinity)
                                              : newQty.clamp(
                                                  0,
                                                  line.product.availableQty,
                                                ))
                                          .toDouble();
                                  if (_allowsPrimaryOverstock && !_scrapSum) {
                                    line.quantity = line.soQty ?? line.quantity;
                                  }
                                  _syncSingleLotFromLine(line);
                                });
                              },
                              onQcQtyChanged: (newQty) {
                                setState(() {
                                  line.qcQty =
                                      (_allowsPrimaryOverstock
                                              ? newQty.clamp(0, double.infinity)
                                              : newQty.clamp(
                                                  0,
                                                  line.product.availableQty,
                                                ))
                                          .toDouble();
                                  if (_allowsPrimaryOverstock && !_scrapSum) {
                                    line.quantity = line.qcQty ?? line.quantity;
                                  }
                                  _syncSingleLotFromLine(line);
                                });
                              },
                              onQuantityChanged: (newQty) {
                                setState(() {
                                  line.quantity =
                                      (_allowsPrimaryOverstock
                                              ? newQty.clamp(0, double.infinity)
                                              : newQty.clamp(
                                                  0,
                                                  line.product.availableQty,
                                                ))
                                          .toDouble();
                                  _syncSingleLotFromLine(line);
                                  // trigger rebuild
                                  _allocatedQty(line);
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
                child: widget.scrapId == null
                    ? SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: provider.isLoading ? null : _createScrap,
                          icon: const Icon(Icons.inventory),
                          label: const Text('Process Scrap'),
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
                          if (auth.canCancelScrapFor(widget.moduleType)) ...[
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
                          if (auth.canSaveScrapFor(widget.moduleType)) ...[
                            if (auth.canCancelScrapFor(widget.moduleType))
                              const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: provider.isLoading
                                    ? null
                                    : () => _createScrap(sendToSalesOperation: false),
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
                          if (auth.canSendToSalesOperationScrapFor(widget.moduleType)) ...[
                            if (auth.canCancelScrapFor(widget.moduleType) ||
                                auth.canSaveScrapFor(widget.moduleType))
                              const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: provider.isLoading
                                    ? null
                                    : () => _createScrap(sendToSalesOperation: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Send to Sales Operation',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                          if (auth.canValidateScrapFor(widget.moduleType)) ...[
                            if (auth.canCancelScrapFor(widget.moduleType) ||
                                auth.canSaveScrapFor(widget.moduleType) ||
                                auth.canSendToSalesOperationScrapFor(widget.moduleType))
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

class _ScrapLineCard extends StatelessWidget {
  const _ScrapLineCard({
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
    this.canEditQcQty = false,
    this.scrapSum = false,
    this.onQuantityChanged,
    this.onSoQtyChanged,
    this.onQcQtyChanged,
    this.onWQcQtyChanged,
    this.onWNonsaleableQtyChanged,
    this.onActualQcQtyChanged,
    this.onQcNonsaleableQtyChanged,
    this.onLotQtyInput,
    this.onLotFieldChanged,
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

  /// Sales-operation permission over the Actual QC / QC Non-saleable pair.
  final bool canEditQcQty;

  /// Renders the four-column scrap form instead of the legacy
  /// SO / Warehouse / Effective one. Set from the picking's `qc_mode`.
  final bool scrapSum;
  final ValueChanged<double>? onQuantityChanged;
  final ValueChanged<double>? onSoQtyChanged;
  final ValueChanged<double>? onQcQtyChanged;
  final ValueChanged<double>? onWQcQtyChanged;
  final ValueChanged<double>? onWNonsaleableQtyChanged;
  final ValueChanged<double>? onActualQcQtyChanged;
  final ValueChanged<double>? onQcNonsaleableQtyChanged;
  final void Function(TransferLotInput lotInput, double quantity)?
  onLotQtyInput;

  /// Scrap-mode lot edits, keyed by wire field name, so the form does not have
  /// to thread four separate callbacks down through the line card.
  final void Function(TransferLotInput lotInput, String field, double value)?
  onLotFieldChanged;

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
                      child: _ScrapLotRow(
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
                        canEditQcQty: canEditQcQty,
                        scrapSum: scrapSum,
                        onLotFieldChanged: onLotFieldChanged,
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
                        'Total Scrap Qty:',
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
                    // On a transit leg the SO figure was fixed at creation and
                    // is shown for reference only.
                    isReadOnly: isReadOnly || scrapSum || !canEditSoQty,
                    min: 0,
                    max: allowOverstock
                        ? double.infinity
                        : line.product.availableQty,
                    onChanged: onSoQtyChanged,
                  ),
                  if (scrapSum) ...[
                    // Each role sees only its own pair. No maximum on any of
                    // them: sales operation may declare more than the return
                    // delivered, and the backend allows it.
                    if (canEditWarehouseQty) ...[
                      _buildQtyRow(
                        title: 'Warehouse QC',
                        value: line.wQcQty ?? 0,
                        isReadOnly: isReadOnly,
                        min: 0,
                        max: double.infinity,
                        onChanged: onWQcQtyChanged,
                      ),
                      _buildQtyRow(
                        title: 'Warehouse Non-saleable',
                        value: line.wNonsaleableQty ?? 0,
                        isReadOnly: isReadOnly,
                        min: 0,
                        max: double.infinity,
                        onChanged: onWNonsaleableQtyChanged,
                      ),
                    ],
                    if (canEditQcQty) ...[
                      _buildQtyRow(
                        title: 'Actual QC',
                        value: line.actualQcQty ?? 0,
                        isReadOnly: isReadOnly,
                        min: 0,
                        max: double.infinity,
                        onChanged: onActualQcQtyChanged,
                      ),
                      _buildQtyRow(
                        title: 'QC Non-saleable',
                        value: line.qcNonsaleableQty ?? 0,
                        isReadOnly: isReadOnly,
                        min: 0,
                        max: double.infinity,
                        onChanged: onQcNonsaleableQtyChanged,
                      ),
                    ],
                  ] else ...[
                    if (canEditWarehouseQty)
                      _buildQtyRow(
                        title: 'Warehouse Qty',
                        value: line.qcQty ?? 0,
                        isReadOnly: isReadOnly,
                        min: 0,
                        max: allowOverstock
                            ? double.infinity
                            : line.product.availableQty,
                        onChanged: onQcQtyChanged,
                      ),
                    if (canEditEffectiveQty)
                      _buildQtyRow(
                        title: 'QC Qty (Effective)',
                        value: line.quantity,
                        isReadOnly: isReadOnly,
                        min: 0,
                        max: allowOverstock
                            ? double.infinity
                            : line.product.availableQty,
                        onChanged: onQuantityChanged,
                      ),
                  ],
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

class _ScrapLotRow extends StatelessWidget {
  const _ScrapLotRow({
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
    this.canEditQcQty = false,
    this.scrapSum = false,
    this.onLotFieldChanged,
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
  final bool canEditQcQty;
  final bool scrapSum;

  /// One callback for all four scrap quantities, keyed by wire field name.
  final void Function(TransferLotInput lotInput, String field, double value)?
  onLotFieldChanged;

  @override
  Widget build(BuildContext context) {
    if (scrapSum) {
      return _buildSplitLayout();
    }
    double activeQty = lotInput.quantity;
    String label = 'Scrap Qty';
    if (canEditSoQty) {
      activeQty = lotInput.soQty ?? lotInput.quantity;
      label = 'SO Qty';
    } else if (canEditWarehouseQty) {
      activeQty = lotInput.qcQty ?? lotInput.quantity;
      label = 'QC Qty';
    } else {
      activeQty = lotInput.quantity;
      label = 'Scrap Qty';
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
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lot Reference',
                style: TextStyle(color: Colors.black54, fontSize: 12),
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
                    horizontal: 8,
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
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
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
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: const Color(0xFFDDE6F2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SSQtyField(
                        value: activeQty.toStringAsFixed(0),
                        isDecimal: true,
                        width: double.infinity,
                        height: 36,
                        enabled: !isReadOnly && onQuantityChanged != null,
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && onQuantityChanged != null) {
                            onQuantityChanged!(parsed);
                          }
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
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
                      ),
                    ),
                    if (!isReadOnly) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onMinus,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.remove,
                            size: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: onPlus,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.add,
                            size: 18,
                            color: Colors.black87,
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
        if (!isReadOnly) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ],
    );
  }

  /// Lot row for a damaged or quality return's transit leg.
  ///
  /// The lot picker gets its own line and the four quantities stack beneath it.
  /// The legacy layout puts the picker and a single stepper side by side, which
  /// has room for one quantity, not four.
  Widget _buildSplitLayout() {
    final displayLots = List<TransferLot>.from(lots);
    if (lotInput.lot != null &&
        !displayLots.any((l) => l.lotId == lotInput.lot!.lotId)) {
      displayLots.add(lotInput.lot!);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: const Color(0xFFDDE6F2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Lot Reference',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const Spacer(),
              if (!isReadOnly)
                InkWell(
                  onTap: onRemove,
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.black45,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: lotInput.lot?.lotId,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: Colors.white,
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
                    child: Text(lot.lotName, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: isReadOnly
                ? null
                : (value) {
                    TransferLot? selected;
                    for (final lot in displayLots) {
                      if (lot.lotId == value) {
                        selected = lot;
                        break;
                      }
                    }
                    onChanged(selected);
                  },
          ),
          if (lotInput.soQty != null && lotInput.soQty! > 0) ...[
            const SizedBox(height: 6),
            Text(
              'SO Qty: ${lotInput.soQty!.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Each role sees only its own pair, as on the line-level rows.
          if (canEditWarehouseQty) ...[
            _splitField('Warehouse QC', lotInput.wQcQty, 'w_qc_qty'),
            _splitField(
              'Warehouse Non-saleable',
              lotInput.wNonsaleableQty,
              'w_nonsaleable_qty',
            ),
          ],
          if (canEditQcQty) ...[
            _splitField('Actual QC', lotInput.actualQcQty, 'actual_qc_qty'),
            _splitField(
              'QC Non-saleable',
              lotInput.qcNonsaleableQty,
              'qc_nonsaleable_qty',
            ),
          ],
        ],
      ),
    );
  }

  /// One quantity input on a scrap lot row. Only called for fields the current
  /// role owns, so there is no permission argument — visibility is the gate.
  Widget _splitField(String label, double? value, String field) {
    final text = (value ?? 0).toStringAsFixed(0);
    final enabled = !isReadOnly && onLotFieldChanged != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
          SSQtyField(
            value: text,
            isDecimal: true,
            width: 72,
            height: 34,
            enabled: enabled,
            onChanged: (val) {
              final parsed = double.tryParse(val);
              if (parsed != null) {
                onLotFieldChanged?.call(lotInput, field, parsed);
              }
            },
          ),
        ],
      ),
    );
  }
}
