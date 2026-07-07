import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

import 'package:secondary_sales/data/models/inventory/virtual_location.dart';
import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/transfers/transfer_provider.dart';
import 'package:secondary_sales/features/transfers/screens/virtual_transfer_detail_screen.dart';

class VanLoadFormScreen extends StatefulWidget {
  const VanLoadFormScreen({super.key, this.isLoad = true, this.existingTransfer});
  
  final bool isLoad;
  final VirtualTransfer? existingTransfer;

  @override
  State<VanLoadFormScreen> createState() => _VanLoadFormScreenState();
}

class _TargetItem {
  final int productId;
  final String productName;
  final String sku;
  final String tracking;
  final String uomName;
  final double targetQty;
  final double availableStock;
  final double scrapStock;
  double demandQty;
  double freshUnloadQty;
  double scrapUnloadQty;

  _TargetItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.tracking,
    required this.uomName,
    required this.targetQty,
    required this.availableStock,
    this.scrapStock = 0.0,
    this.demandQty = 0.0,
    this.freshUnloadQty = 0.0,
    this.scrapUnloadQty = 0.0,
  });
}

class _VanLoadFormScreenState extends State<VanLoadFormScreen> {
  int? _selectedDestinationId;
  List<_TargetItem> _items = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransferProvider>().prepareVirtualTransfer().then((_) {
        if (!mounted) return;
        final prepare = context.read<TransferProvider>().transferPrepare;
        final destinations = _uniqueDestinations(prepare?.destinationLocations ?? []);
        if (widget.existingTransfer != null) {
          setState(() {
            _selectedDestinationId = widget.existingTransfer!.destinationLocation?['id'];
          });
        } else if (destinations.isNotEmpty) {
          setState(() {
            _selectedDestinationId = destinations.first.id;
          });
        }
        _fetchTargets();
      });
    });
  }

  Future<void> _fetchTargets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final employeeId = context.read<AuthProvider>().employeeId;
      if (employeeId == null) throw Exception('No active employee ID found.');

      final rawTargets = await context.read<TransferProvider>().getVanLoadingTargets(
        employeeId: employeeId,
        date: DateTime.now(),
        vanOperationType: widget.existingTransfer != null
            ? widget.existingTransfer!.vanOperationType
            : (widget.isLoad ? 'load' : 'unload'),
        destinationLocationId: _selectedDestinationId,
      );

      final items = <_TargetItem>[];
      for (final t in rawTargets) {
        final productId = t['product_id'] ?? 0;
        final avail = (t['available_stock'] ?? 0.0).toDouble();
        final scrap = (t['scrap_stock'] ?? 0.0).toDouble();

        double demand = 0.0;
        double freshUnload = avail;
        double scrapUnload = scrap;

        if (widget.existingTransfer != null) {
          final existingLine = widget.existingTransfer!.lines.firstWhere(
            (l) => l.product?['id'] == productId,
            orElse: () => VirtualTransferLine(
              moveId: 0,
              state: '',
              demandQty: 0.0,
              quantity: 0.0,
              scrapQty: 0.0,
              lotLines: [],
            ),
          );
          if (existingLine.moveId > 0) {
            final isLoadTransfer = widget.existingTransfer!.vanOperationType != 'unload';
            if (isLoadTransfer) {
              demand = existingLine.demandQty;
            } else {
              scrapUnload = existingLine.scrapQty;
              freshUnload = existingLine.quantity - existingLine.scrapQty;
            }
          } else {
            demand = 0.0;
            freshUnload = 0.0;
            scrapUnload = 0.0;
          }
        } else {
          demand = 0.0;
          freshUnload = avail;
          scrapUnload = scrap;
        }

        items.add(_TargetItem(
          productId: productId,
          productName: t['product_name'] ?? 'Unknown',
          sku: t['sku'] ?? '',
          tracking: t['tracking'] ?? 'none',
          uomName: t['uom_name'] ?? 'Unit',
          targetQty: (t['daily_target_qty'] ?? 0.0).toDouble(),
          availableStock: avail,
          scrapStock: scrap,
          demandQty: demand,
          freshUnloadQty: freshUnload,
          scrapUnloadQty: scrapUnload,
        ));
      }

      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _validateAndSubmit() async {
    if (_selectedDestinationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Van Name (Destination).')),
      );
      return;
    }

    final lines = <VirtualTransferLineEntry>[];
    for (final item in _items) {
      if (widget.isLoad) {
        if (item.demandQty > 0) {
          final product = TransferProduct(
            id: item.productId,
            name: item.productName,
            code: item.sku,
            tracking: item.tracking,
            availableQty: item.availableStock,
          );
          lines.add(VirtualTransferLineEntry(
            product: product,
            quantity: item.demandQty,
          ));
        }
      } else {
        if (item.freshUnloadQty > 0 || item.scrapUnloadQty > 0) {
          final product = TransferProduct(
            id: item.productId,
            name: item.productName,
            code: item.sku,
            tracking: item.tracking,
            availableQty: item.availableStock,
          );
          lines.add(VirtualTransferLineEntry(
            product: product,
            quantity: item.freshUnloadQty + item.scrapUnloadQty,
            freshQty: item.freshUnloadQty,
            scrapQty: item.scrapUnloadQty,
          ));
        }
      }
    }

    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isLoad
                ? 'Please enter demand quantity for at least one item.'
                : 'Please enter unload quantity for at least one item.',
          ),
        ),
      );
      return;
    }

    final VirtualTransfer? transfer;
    if (widget.existingTransfer != null) {
      transfer = await context.read<TransferProvider>().updateVirtualTransfer(
        widget.existingTransfer!.id,
        destinationLocationId: _selectedDestinationId!,
        lines: lines,
        vanOperationType: widget.existingTransfer!.vanOperationType,
      );
    } else {
      transfer = await context.read<TransferProvider>().createVirtualTransfer(
        destinationLocationId: _selectedDestinationId!,
        lines: lines,
        vanOperationType: widget.isLoad ? 'load' : 'unload',
      );
    }

    if (!mounted) return;
    if (transfer == null) {
      final error = context.read<TransferProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to save van operation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.existingTransfer != null) {
      Navigator.pop(context, transfer);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VirtualTransferDetailScreen(initialTransfer: transfer!),
      ),
    );
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

    final selectedDestination = destinations.firstWhere(
      (d) => d.id == _selectedDestinationId,
      orElse: () => destinations.isNotEmpty ? destinations.first : VirtualLocation(id: 0, name: '', usage: ''),
    );
    final distributor = selectedDestination.id > 0
        ? selectedDestination.distributor ?? prepare?.distributor
        : prepare?.distributor;
    final source = distributor?['customer_stock_location'];
    final sourceLocation = source is Map
        ? source.cast<String, dynamic>()
        : prepare?.sourceLocation;
    final sourceLocationName = sourceLocation?['name']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryStrong),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingTransfer != null
              ? 'Edit ${widget.existingTransfer!.name}'
              : (widget.isLoad ? 'Van Load Form' : 'Van Unload Form'),
          style: const TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.existingTransfer == null)
            IconButton(
              icon: const Icon(Icons.sync, color: AppColors.primaryStrong),
              onPressed: _fetchTargets,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading || (provider.isLoading && prepare == null)
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_error != null) ErrorPanel(_error!),
                        
                        const Text(
                          'Van Name',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDDE6F2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedDestinationId,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                              items: destinations.map((location) {
                                final displayName = location.name.split('/').last;
                                return DropdownMenuItem(
                                  value: location.id,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          displayName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: widget.existingTransfer != null ? null : (value) {
                                setState(() {
                                  _selectedDestinationId = value;
                                });
                                _fetchTargets();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          widget.isLoad ? 'Source Location' : 'Destination Location',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDDE6F2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  sourceLocationName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        if (widget.isLoad) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Load Items',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${_items.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFDDE6F2)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _items.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFDDE6F2)),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SKU #${item.sku.isNotEmpty ? item.sku : item.productId}',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.productName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'TARGET QTY',
                                                  style: TextStyle(
                                                    color: AppColors.primaryStrong,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF3F6FA),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFDDE6F2)),
                                                  ),
                                                  child: Text(
                                                    item.targetQty.toStringAsFixed(0),
                                                    style: const TextStyle(
                                                      color: AppColors.textSecondary,
                                                      fontWeight: FontWeight.w500,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'DEMAND QTY',
                                                  style: TextStyle(
                                                    color: AppColors.primaryStrong,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                SizedBox(
                                                  height: 42,
                                                  child: TextField(
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: InputDecoration(
                                                      hintText: 'Enter qty',
                                                      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: const BorderSide(color: AppColors.primary),
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: const BorderSide(color: AppColors.primary),
                                                      ),
                                                    ),
                                                    onChanged: (val) {
                                                      final qty = double.tryParse(val) ?? 0;
                                                      setState(() {
                                                        // Cap at available stock
                                                        if (qty > item.availableStock) {
                                                          item.demandQty = item.availableStock;
                                                        } else {
                                                          item.demandQty = qty;
                                                        }
                                                      });
                                                    },
                                                    controller: TextEditingController(
                                                      text: item.demandQty > 0 ? item.demandQty.toStringAsFixed(0) : '',
                                                    )..selection = TextSelection.collapsed(offset: item.demandQty > 0 ? item.demandQty.toStringAsFixed(0).length : 0),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Available Stock: ${item.availableStock.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: item.availableStock < item.targetQty
                                                ? Colors.orange
                                                : AppColors.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Unload Items',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${_items.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFDDE6F2)),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'SKU #${item.sku.isNotEmpty ? item.sku : item.productId}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Fresh Qty',
                                                style: TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                height: 42,
                                                child: TextField(
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  decoration: InputDecoration(
                                                    hintText: 'Enter qty',
                                                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: const BorderSide(color: Color(0xFFDDE6F2)),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: const BorderSide(color: Color(0xFFDDE6F2)),
                                                    ),
                                                  ),
                                                  onChanged: (val) {
                                                    final qty = double.tryParse(val) ?? 0;
                                                    setState(() {
                                                      if (qty > item.availableStock) {
                                                        item.freshUnloadQty = item.availableStock;
                                                      } else {
                                                        item.freshUnloadQty = qty;
                                                      }
                                                    });
                                                  },
                                                  controller: TextEditingController(
                                                    text: item.freshUnloadQty > 0 ? item.freshUnloadQty.toStringAsFixed(0) : '',
                                                  )..selection = TextSelection.collapsed(
                                                      offset: item.freshUnloadQty > 0 ? item.freshUnloadQty.toStringAsFixed(0).length : 0,
                                                    ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Scrap Qty',
                                                style: TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                height: 42,
                                                child: TextField(
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  decoration: InputDecoration(
                                                    hintText: 'Enter qty',
                                                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: const BorderSide(color: Color(0xFFDDE6F2)),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: const BorderSide(color: Color(0xFFDDE6F2)),
                                                    ),
                                                  ),
                                                  onChanged: (val) {
                                                    final qty = double.tryParse(val) ?? 0;
                                                    setState(() {
                                                      if (qty > item.scrapStock) {
                                                        item.scrapUnloadQty = item.scrapStock;
                                                      } else {
                                                        item.scrapUnloadQty = qty;
                                                      }
                                                    });
                                                  },
                                                  controller: TextEditingController(
                                                    text: item.scrapUnloadQty > 0 ? item.scrapUnloadQty.toStringAsFixed(0) : '',
                                                  )..selection = TextSelection.collapsed(
                                                      offset: item.scrapUnloadQty > 0 ? item.scrapUnloadQty.toStringAsFixed(0).length : 0,
                                                    ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Available Fresh: ${item.availableStock.toStringAsFixed(0)} | Scrap: ${item.scrapStock.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ]
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: provider.isLoading || _isLoading ? null : _validateAndSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: provider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Validate',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
