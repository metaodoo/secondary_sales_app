import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_stock_audit.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';

class MtStockAuditCreateScreen extends StatefulWidget {
  final int? outletId;
  final String? outletName;
  final int? visitId;
  final MtStockAudit? editAudit;

  const MtStockAuditCreateScreen({
    super.key,
    this.outletId,
    this.outletName,
    this.visitId,
    this.editAudit,
  });

  @override
  State<MtStockAuditCreateScreen> createState() => _MtStockAuditCreateScreenState();
}

class _MtStockAuditCreateScreenState extends State<MtStockAuditCreateScreen> {
  String _selectedType = 'opening_stock';
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<MtStockAuditProduct> _availableProducts = [];
  bool _isLoadingProducts = false;
  bool _isSubmitting = false;

  // Selected audit lines: key is product_id (or product_id + lot_id)
  final Map<int, _AuditEntry> _entries = {};

  @override
  void initState() {
    super.initState();
    if (widget.editAudit != null) {
      _selectedType = widget.editAudit!.type;
      _notesController.text = widget.editAudit!.notes;
      for (final line in widget.editAudit!.lines) {
        _entries[line.productId] = _AuditEntry(
          productId: line.productId,
          productName: line.productName,
          defaultCode: line.defaultCode,
          uomName: line.uomName,
          lotId: line.lotId,
          lotName: line.lotName,
          stockCount: line.stockCount,
        );
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProducts());
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    final prods = await context.read<ModernTradeProvider>().fetchAuditProducts(
      search: _searchController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _availableProducts = prods;
      _isLoadingProducts = false;
    });
  }

  double get _totalQuantity {
    return _entries.values.fold(0.0, (sum, item) => sum + item.stockCount);
  }

  int get _totalLinesCount {
    return _entries.values.where((item) => item.stockCount > 0).length;
  }

  void _updateQuantity(MtStockAuditProduct prod, int? lotId, String? lotName, double newQty) {
    setState(() {
      if (newQty <= 0) {
        _entries.remove(prod.id);
      } else {
        _entries[prod.id] = _AuditEntry(
          productId: prod.id,
          productName: prod.name,
          defaultCode: prod.defaultCode,
          uomName: prod.uomName,
          lotId: lotId,
          lotName: lotName,
          stockCount: newQty,
        );
      }
    });
  }

  Future<void> _submitAudit({required bool confirm}) async {
    final activeLines = _entries.values.where((e) => e.stockCount > 0).toList();
    if (activeLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter stock count for at least one product.')),
      );
      return;
    }

    final effectiveOutletId = widget.outletId ?? widget.editAudit?.outletId;
    if (effectiveOutletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing outlet information.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final linesPayload = activeLines.map((e) => e.toPayload()).toList();
      final provider = context.read<ModernTradeProvider>();

      if (widget.editAudit != null) {
        await provider.updateStockAudit(
          auditId: widget.editAudit!.id,
          outletId: effectiveOutletId,
          type: _selectedType,
          lines: linesPayload,
          visitId: widget.visitId ?? widget.editAudit!.visitId,
          notes: _notesController.text.trim(),
          confirm: confirm,
        );
      } else {
        await provider.createStockAudit(
          outletId: effectiveOutletId,
          type: _selectedType,
          lines: linesPayload,
          visitId: widget.visitId,
          notes: _notesController.text.trim(),
          confirm: confirm,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirm
                ? 'Stock Audit confirmed successfully!'
                : 'Stock Audit saved as draft.',
          ),
          backgroundColor: confirm ? const Color(0xFF10B981) : AppColors.primaryStrong,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            BlueHeader(
              title: widget.editAudit != null ? 'Edit Stock Audit' : 'New Stock Audit',
              subtitle: widget.outletName ?? widget.editAudit?.outletName ?? 'Modern Trade',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Header Settings Panel
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Audit Type',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTypeRadio('Opening', 'opening_stock'),
                        const SizedBox(width: 8),
                        _buildTypeRadio('Stock In', 'stock_in'),
                        const SizedBox(width: 8),
                        _buildTypeRadio('Closing', 'closing_stock'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Product Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _loadProducts(),
                decoration: InputDecoration(
                  hintText: 'Search products by name or code...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    onPressed: _loadProducts,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Product List with Quantity Controls
            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator())
                  : _availableProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'No products found.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _availableProducts.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final prod = _availableProducts[index];
                            final entry = _entries[prod.id];
                            return _ProductAuditCard(
                              product: prod,
                              entry: entry,
                              onQuantityChanged: (lotId, lotName, qty) {
                                _updateQuantity(prod, lotId, lotName, qty);
                              },
                            );
                          },
                        ),
            ),
            // Bottom Summary & Actions Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFDDE6F2))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Items: $_totalLinesCount',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Total Qty: $_totalQuantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primaryStrong,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : () => _submitAudit(confirm: false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryStrong),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text(
                            'Save as Draft',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryStrong),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : () => _submitAudit(confirm: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Confirm Audit',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
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
    );
  }

  Widget _buildTypeRadio(String label, String value) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryStrong : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuditEntry {
  final int productId;
  final String productName;
  final String? defaultCode;
  final String? uomName;
  final int? lotId;
  final String? lotName;
  final double stockCount;

  _AuditEntry({
    required this.productId,
    required this.productName,
    this.defaultCode,
    this.uomName,
    this.lotId,
    this.lotName,
    required this.stockCount,
  });

  Map<String, dynamic> toPayload() {
    return {
      'product_id': productId,
      if (lotId != null) 'lot_id': lotId,
      'stock_count': stockCount,
    };
  }
}

class _ProductAuditCard extends StatefulWidget {
  final MtStockAuditProduct product;
  final _AuditEntry? entry;
  final void Function(int? lotId, String? lotName, double quantity) onQuantityChanged;

  const _ProductAuditCard({
    required this.product,
    required this.entry,
    required this.onQuantityChanged,
  });

  @override
  State<_ProductAuditCard> createState() => _ProductAuditCardState();
}

class _ProductAuditCardState extends State<_ProductAuditCard> {
  int? _selectedLotId;
  String? _selectedLotName;
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _selectedLotId = widget.entry?.lotId ?? (widget.product.lots.isNotEmpty ? widget.product.lots.first.id : null);
    _selectedLotName = widget.entry?.lotName ?? (widget.product.lots.isNotEmpty ? widget.product.lots.first.name : null);
    _qtyController = TextEditingController(
      text: widget.entry != null && widget.entry!.stockCount > 0
          ? widget.entry!.stockCount.toString()
          : '',
    );
  }

  @override
  void didUpdateWidget(covariant _ProductAuditCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry != oldWidget.entry) {
      final newText = widget.entry != null && widget.entry!.stockCount > 0
          ? widget.entry!.stockCount.toString()
          : '';
      if (_qtyController.text != newText) {
        _qtyController.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _setQty(double val) {
    final clamped = val < 0 ? 0.0 : val;
    _qtyController.text = clamped > 0 ? clamped.toString() : '';
    widget.onQuantityChanged(_selectedLotId, _selectedLotName, clamped);
  }

  @override
  Widget build(BuildContext context) {
    final hasQty = (widget.entry?.stockCount ?? 0) > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasQty ? AppColors.primaryStrong : AppColors.borderSoft,
          width: hasQty ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (widget.product.defaultCode != null)
                      Text(
                        'Code: ${widget.product.defaultCode}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (widget.product.uomName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.product.uomName!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
          if (widget.product.lots.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedLotId,
                  hint: const Text('Select Lot & Expiry', style: TextStyle(fontSize: 12)),
                  items: widget.product.lots.map((lot) {
                    return DropdownMenuItem<int>(
                      value: lot.id,
                      child: Text(
                        lot.displayName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedLotId = val;
                      final lot = widget.product.lots.firstWhere((l) => l.id == val);
                      _selectedLotName = lot.name;
                    });
                    final currentQty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
                    widget.onQuantityChanged(_selectedLotId, _selectedLotName, currentQty);
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Count:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.primaryStrong),
                    onPressed: () {
                      final current = double.tryParse(_qtyController.text.trim()) ?? 0.0;
                      if (current > 0) _setQty(current - 1);
                    },
                  ),
                  SizedBox(
                    width: 70,
                    height: 36,
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.borderSoft),
                        ),
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val.trim()) ?? 0.0;
                        widget.onQuantityChanged(_selectedLotId, _selectedLotName, parsed);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryStrong),
                    onPressed: () {
                      final current = double.tryParse(_qtyController.text.trim()) ?? 0.0;
                      _setQty(current + 1);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
