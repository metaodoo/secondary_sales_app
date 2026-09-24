import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_return_request.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/modern_trade/mt_return_provider.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_line_edit_sheet.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_line_history_sheet.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_product_selection_sheet.dart';
import 'package:secondary_sales/features/sales/screens/validate_delivery_screen.dart';

class MtReturnDetailScreen extends StatefulWidget {
  final int returnId;

  const MtReturnDetailScreen({
    super.key,
    required this.returnId,
  });

  @override
  State<MtReturnDetailScreen> createState() => _MtReturnDetailScreenState();
}

class _MtReturnDetailScreenState extends State<MtReturnDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MtReturnProvider>().fetchReturnDetail(widget.returnId);
    });
  }

  void _onExecuteAction(String action, String actionLabel) async {
    final isConfirmAction = actionLabel.toLowerCase().startsWith('confirm');
    final dialogTitle = isConfirmAction ? 'Confirm Return Request' : 'Confirm $actionLabel';
    final dialogContent = isConfirmAction
        ? 'Are you sure you want to confirm this return request?'
        : 'Are you sure you want to $actionLabel this return request?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dialogTitle),
        content: Text(dialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryStrong),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<MtReturnProvider>();
      final success = await provider.executeAction(widget.returnId, action);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$actionLabel completed successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else if (provider.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _onEditOrSplitLine(MtReturnRequestLine line, MtReturnRequest rr) async {
    final updatedLineDataList = await MtReturnLineEditSheet.show(
      context,
      line: line,
      returnBucket: rr.returnBucket,
    );

    if (updatedLineDataList != null && updatedLineDataList.isNotEmpty && mounted) {
      final existingLinesPayload = <Map<String, dynamic>>[];

      // Keep other product lines as is
      for (final l in rr.lines) {
        if (l.id != line.id) {
          existingLinesPayload.add({
            'id': l.id,
            'product_id': l.productId,
            'lot_id': l.lotId,
            'saleable_qty': l.saleableQty,
            'non_saleable_qty': l.nonSaleableQty,
            'quality_qty': l.qualityQty,
          });
        }
      }

      // Add updated and newly split line(s)
      existingLinesPayload.addAll(updatedLineDataList);

      final provider = context.read<MtReturnProvider>();
      final ok = await provider.updateReturnLines(widget.returnId, existingLinesPayload);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lines updated and lots split successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (provider.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _onAddNewProductLine(MtReturnRequest rr) async {
    final result = await MtReturnProductSelectionSheet.show(
      context,
      returnBucket: rr.returnBucket,
    );
    if (result != null && mounted) {
      final existingLinesPayload = rr.lines.map((l) => {
        'id': l.id,
        'product_id': l.productId,
        'lot_id': l.lotId,
        'saleable_qty': l.saleableQty,
        'non_saleable_qty': l.nonSaleableQty,
        'quality_qty': l.qualityQty,
      }).toList();

      existingLinesPayload.add({
        'product_id': result['product_id'],
        'lot_id': result['lot_id'],
        'saleable_qty': result['saleable_qty'],
        'non_saleable_qty': result['non_saleable_qty'],
        'quality_qty': result['quality_qty'],
      });

      final provider = context.read<MtReturnProvider>();
      final ok = await provider.updateReturnLines(widget.returnId, existingLinesPayload);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product line added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (provider.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MtReturnProvider>();
    final auth = context.watch<AuthProvider>();
    final rr = provider.selectedReturn;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(rr != null ? rr.name : 'Return Request Detail'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchReturnDetail(widget.returnId),
          ),
        ],
      ),
      body: provider.isLoading && rr == null
          ? const Center(child: CircularProgressIndicator())
          : rr == null
              ? Center(
                  child: Text(
                    provider.errorMessage ?? 'Return request not found.',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => provider.fetchReturnDetail(widget.returnId),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Status & Outlet Card
                        _buildHeaderCard(rr),
                        const SizedBox(height: 16),

                        // Linked Transfers Section
                        _buildTransfersSection(rr),
                        const SizedBox(height: 16),

                        // Lines Section
                        _buildLinesSection(rr, auth),
                        const SizedBox(height: 80), // bottom space for sticky buttons
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: rr != null ? _buildBottomActionBar(rr, auth, provider) : null,
    );
  }

  Widget _buildHeaderCard(MtReturnRequest rr) {
    final isSaleable = rr.isSaleable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rr.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              _buildStatusBadge(rr.state, rr.stateDisplay),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSaleable ? Colors.teal.shade50 : Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isSaleable ? Colors.teal.shade300 : Colors.purple.shade300),
                ),
                child: Text(
                  rr.returnBucketDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSaleable ? Colors.teal.shade800 : Colors.purple.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (rr.date != null)
                Text(
                  'Date: ${rr.date}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
          const Divider(height: 20),
          // Outlet Info
          Text(
            rr.partnerName ?? 'Outlet',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (rr.ssCode != null && rr.ssCode!.isNotEmpty)
            Text('SS Code: ${rr.ssCode}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          if (rr.zoneName != null)
            Text('Zone: ${rr.zoneName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          if (rr.warehouseName != null)
            Text('Warehouse: ${rr.warehouseName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          if (rr.returnScrapLocationName != null)
            Text('Scrap Loc: ${rr.returnScrapLocationName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildTransfersSection(MtReturnRequest rr) {
    final transfers = rr.transfers
        .where((t) =>
            t.isDelivery || t.pickingTypeCode.toLowerCase() == 'outgoing')
        .toList();

    if (transfers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: AppColors.primaryStrong, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery (${transfers.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transfers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final t = transfers[index];
              return Material(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final provider = context.read<MtReturnProvider>();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ValidateDeliveryScreen(
                          orderId: 0,
                          orderName: rr.name,
                          pickingId: t.id,
                          pickingName: t.name,
                          pickingState: t.state,
                          isReceipt: false,
                          saleType: 'primary',
                          businessType: 'mt',
                        ),
                      ),
                    );
                    if (mounted) {
                      provider.fetchReturnDetail(widget.returnId);
                    }
                  },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        t.name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.open_in_new, size: 14, color: AppColors.primaryStrong),
                                  ],
                                ),
                              ),
                              _buildTransferStateBadge(t.state, t.stateDisplay),
                            ],
                          ),
                          if (t.origin != null) ...[
                            const SizedBox(height: 2),
                            Text('Origin: ${t.origin}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildChip(t.pickingTypeName, Colors.blue),
                              if (t.isParent)
                                _buildChip('Parent Transfer', Colors.teal)
                              else if (t.parentTransferName != null)
                                _buildChip('Child of ${t.parentTransferName}', Colors.indigo),
                            ],
                          ),
                          if (t.moves.isNotEmpty) ...[
                            const Divider(height: 16),
                            ...t.moves.map((m) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '• ${m.productName}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'Demand: ${m.demandQty.toStringAsFixed(0)} ${m.uomName}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLinesSection(MtReturnRequest rr, AuthProvider auth) {
    final isSaleable = rr.isSaleable;
    final lines = rr.lines;
    final nextAction = rr.allowedActions.nextAction;
    final actionKey = _getActionAccessKey(nextAction);
    final canPerformCurrentStage = nextAction != null && (actionKey == null || auth.canDo(actionKey));
    final canEditLines = !rr.isConfirmed &&
        auth.canDo(AppAction.mtReturnsSave) &&
        canPerformCurrentStage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Returned Products (${lines.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  if (canEditLines)
                    TextButton.icon(
                      onPressed: () => _onAddNewProductLine(rr),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.primaryStrong),
                      label: const Text(
                        'Add Product',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryStrong),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    'Total Qty: ${rr.totalQty.toStringAsFixed(rr.totalQty.truncateToDouble() == rr.totalQty ? 0 : 2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryStrong),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lines.length,
            separatorBuilder: (context, index) => const Divider(height: 20),
            itemBuilder: (context, index) {
              final line = lines[index];
              return Column(
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
                              line.productName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              line.defaultCode != null && line.defaultCode!.isNotEmpty
                                  ? 'Code: ${line.defaultCode} • UoM: ${line.uomName}'
                                  : 'UoM: ${line.uomName}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            if (line.lotName != null && line.lotName!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  'Lot: ${line.lotName}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canEditLines)
                        IconButton(
                          onPressed: () => _onEditOrSplitLine(line, rr),
                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryStrong, size: 22),
                          tooltip: 'Edit & Split Lots',
                        ),
                      // Hamburger details button
                      IconButton(
                        onPressed: () => MtReturnLineHistorySheet.show(
                          context,
                          line: line,
                          returnBucket: rr.returnBucket,
                        ),
                        icon: const Icon(Icons.menu, color: AppColors.primaryStrong),
                        tooltip: 'View Review History',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (isSaleable) ...[
                        _buildQtyChip('Saleable', line.saleableQty, Colors.teal),
                        _buildQtyChip('Non-Saleable', line.nonSaleableQty, Colors.orange),
                      ] else ...[
                        _buildQtyChip('Non-Saleable', line.nonSaleableQty, Colors.orange),
                        _buildQtyChip('Quality', line.qualityQty, Colors.purple),
                      ],
                      _buildQtyChip('Total Qty', line.totalQty, AppColors.primaryStrong, isBold: true),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String? _getActionAccessKey(String? action) {
    if (action == null) return null;
    switch (action.toLowerCase()) {
      case 'submit_dm':
      case 'action_submit_dm':
        return AppAction.mtReturnsSubmitDm;
      case 'submit_kas':
      case 'action_submit_kas':
        return AppAction.mtReturnsSubmitKas;
      case 'submit_supply_chain':
      case 'submit_sc':
      case 'action_submit_supply_chain':
        return AppAction.mtReturnsSubmitSupplyChain;
      case 'submit_qc':
      case 'action_submit_qc':
        return AppAction.mtReturnsSubmitQc;
      case 'submit_sales_operation':
      case 'submit_so':
      case 'action_submit_sales_operation':
        return AppAction.mtReturnsSubmitSalesOperation;
      case 'confirm':
      case 'action_confirm':
        return AppAction.mtReturnsConfirm;
      default:
        return null;
    }
  }

  Widget? _buildBottomActionBar(MtReturnRequest rr, AuthProvider auth, MtReturnProvider provider) {
    if (rr.isConfirmed) return null;

    final actions = rr.allowedActions;
    final nextAction = actions.nextAction;
    final nextLabel = actions.nextActionLabel ?? 'Submit Next Stage';
    final actionKey = _getActionAccessKey(nextAction);

    final canPerformNext = nextAction != null && (actionKey == null || auth.canDo(actionKey));

    if (!canPerformNext) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: provider.isActionLoading
                ? null
                : () => _onExecuteAction(nextAction, nextLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: actions.canConfirm ? Colors.green.shade700 : AppColors.primaryStrong,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: provider.isActionLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    nextLabel,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String state, String label) {
    Color bg;
    Color fg;
    switch (state.toLowerCase()) {
      case 'confirmed':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'sales_operation':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        break;
      case 'qc':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        break;
      case 'supply_chain':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade700;
        break;
      case 'kas':
        bg = Colors.cyan.shade50;
        fg = Colors.cyan.shade800;
        break;
      case 'dm':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      default: // kao
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildTransferStateBadge(String state, String label) {
    final isDone = state == 'done';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDone ? Colors.green.shade300 : Colors.orange.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDone ? Colors.green.shade700 : Colors.orange.shade800,
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildQtyChip(String label, double qty, Color color, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        '$label: ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
