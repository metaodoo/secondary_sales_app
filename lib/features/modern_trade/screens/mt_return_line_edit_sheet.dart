import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_return_request.dart';
import 'package:secondary_sales/features/modern_trade/mt_return_provider.dart';

class MtReturnLineEditSheet extends StatefulWidget {
  final MtReturnRequestLine line;
  final String returnBucket;

  const MtReturnLineEditSheet({
    super.key,
    required this.line,
    required this.returnBucket,
  });

  static Future<List<Map<String, dynamic>>?> show(
    BuildContext context, {
    required MtReturnRequestLine line,
    required String returnBucket,
  }) {
    return showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MtReturnLineEditSheet(
        line: line,
        returnBucket: returnBucket,
      ),
    );
  }

  @override
  State<MtReturnLineEditSheet> createState() => _MtReturnLineEditSheetState();
}

class _LotAllocationEntry {
  final int? lineId;
  int? lotId;
  String? lotName;
  final TextEditingController saleableCtrl;
  final TextEditingController nonSaleableCtrl;
  final TextEditingController qualityCtrl;

  _LotAllocationEntry({
    this.lineId,
    this.lotId,
    this.lotName,
    required double saleableQty,
    required double nonSaleableQty,
    required double qualityQty,
  })  : saleableCtrl = TextEditingController(
          text: saleableQty > 0
              ? saleableQty.toStringAsFixed(saleableQty.truncateToDouble() == saleableQty ? 0 : 2)
              : '0',
        ),
        nonSaleableCtrl = TextEditingController(
          text: nonSaleableQty > 0
              ? nonSaleableQty.toStringAsFixed(nonSaleableQty.truncateToDouble() == nonSaleableQty ? 0 : 2)
              : '0',
        ),
        qualityCtrl = TextEditingController(
          text: qualityQty > 0
              ? qualityQty.toStringAsFixed(qualityQty.truncateToDouble() == qualityQty ? 0 : 2)
              : '0',
        );

  void dispose() {
    saleableCtrl.dispose();
    nonSaleableCtrl.dispose();
    qualityCtrl.dispose();
  }
}

class _MtReturnLineEditSheetState extends State<MtReturnLineEditSheet> {
  final List<_LotAllocationEntry> _entries = [];
  final List<int> _deletedLineIds = [];

  @override
  void initState() {
    super.initState();
    // Initial entry from the tapped line
    _entries.add(_LotAllocationEntry(
      lineId: widget.line.id,
      lotId: widget.line.lotId,
      lotName: widget.line.lotName,
      saleableQty: widget.line.saleableQty,
      nonSaleableQty: widget.line.nonSaleableQty,
      qualityQty: widget.line.qualityQty,
    ));

    // Fetch product lots
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MtReturnProvider>().fetchProductLots(widget.line.productId);
    });
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _onAddSplitLot() {
    setState(() {
      _entries.add(_LotAllocationEntry(
        lineId: null, // New line to be created on backend
        lotId: null,
        lotName: null,
        saleableQty: 0.0,
        nonSaleableQty: 0.0,
        qualityQty: 0.0,
      ));
    });
  }

  void _onRemoveEntry(int index) {
    setState(() {
      final removed = _entries.removeAt(index);
      if (removed.lineId != null) {
        _deletedLineIds.add(removed.lineId!);
      }
      removed.dispose();
    });
  }

  void _onSave() {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one lot entry is required.')),
      );
      return;
    }

    final isSaleable = widget.returnBucket == 'saleable';
    final List<Map<String, dynamic>> results = [];

    // Collect active entries
    for (final entry in _entries) {
      final sQty = double.tryParse(entry.saleableCtrl.text) ?? 0.0;
      final nsQty = double.tryParse(entry.nonSaleableCtrl.text) ?? 0.0;
      final qQty = double.tryParse(entry.qualityCtrl.text) ?? 0.0;

      if (isSaleable && sQty <= 0 && nsQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each line must have a valid quantity > 0.')),
        );
        return;
      }
      if (!isSaleable && nsQty <= 0 && qQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each line must have a valid quantity > 0.')),
        );
        return;
      }

      final Map<String, dynamic> item = {
        'product_id': widget.line.productId,
        'lot_id': entry.lotId,
        'saleable_qty': isSaleable ? sQty : 0.0,
        'non_saleable_qty': nsQty,
        'quality_qty': !isSaleable ? qQty : 0.0,
      };
      if (entry.lineId != null) {
        item['id'] = entry.lineId;
      }
      results.add(item);
    }

    // Add deleted lines
    for (final delId in _deletedLineIds) {
      results.add({
        'id': delId,
        'delete': true,
      });
    }

    Navigator.of(context).pop(results);
  }

  @override
  Widget build(BuildContext context) {
    final isSaleable = widget.returnBucket == 'saleable';
    final provider = context.watch<MtReturnProvider>();
    final lots = provider.availableLots;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit & Split Lots',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.line.productName} • ${widget.line.uomName}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Body: List of Lot Allocation Cards
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final isOriginal = entry.lineId != null;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isOriginal ? Colors.blue.shade50 : Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isOriginal ? Colors.blue.shade200 : Colors.teal.shade200,
                                  ),
                                ),
                                child: Text(
                                  isOriginal ? 'Lot Allocation #${index + 1}' : 'Split Lot #${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isOriginal ? Colors.blue.shade800 : Colors.teal.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_entries.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _onRemoveEntry(index),
                              tooltip: 'Remove Lot',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Lot Selector Dropdown
                      const Text('Lot / Serial Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      provider.isLoadingLots
                          ? const Center(child: Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()))
                          : DropdownButtonFormField<int?>(
                              value: entry.lotId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                hintText: 'Select Lot (Optional)...',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('No Lot / Standard'),
                                ),
                                ...lots.map((lot) {
                                  final id = lot['id'] as int?;
                                  final name = lot['name']?.toString() ?? '';
                                  final exp = lot['expiration_date']?.toString();
                                  final label = exp != null && exp.isNotEmpty ? '$name (Exp: $exp)' : name;
                                  return DropdownMenuItem<int?>(
                                    value: id,
                                    child: Text(label, overflow: TextOverflow.ellipsis),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  entry.lotId = val;
                                  if (val != null) {
                                    try {
                                      final matched = lots.firstWhere((l) => l['id'] == val);
                                      entry.lotName = matched['name']?.toString();
                                    } catch (_) {}
                                  } else {
                                    entry.lotName = null;
                                  }
                                });
                              },
                            ),
                      const SizedBox(height: 12),

                      // Quantities
                      if (isSaleable) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: entry.saleableCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Saleable Qty',
                                  suffixText: widget.line.uomName,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: entry.nonSaleableCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Non-Saleable Qty',
                                  suffixText: widget.line.uomName,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: entry.nonSaleableCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Non-Saleable Qty',
                                  suffixText: widget.line.uomName,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: entry.qualityCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Quality Qty',
                                  suffixText: widget.line.uomName,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _onAddSplitLot,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primaryStrong),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, color: AppColors.primaryStrong, size: 18),
                    label: const Text(
                      'Split / Add Lot',
                      style: TextStyle(color: AppColors.primaryStrong, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryStrong,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
