import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/util/dialog_helper.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_outlet.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:secondary_sales/features/routes/screens/customer_action_bottom_sheet.dart';
import 'package:secondary_sales/features/routes/screens/outlet_visit_history_screen.dart';
import 'package:secondary_sales/data/models/routes/visit_reason.dart';
import 'package:secondary_sales/features/routes/screens/visit_reason_dialog.dart';
import 'package:secondary_sales/features/sales/screens/product_selection_screen.dart';
import 'package:secondary_sales/features/sales/screens/secondary_orders_list_screen.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_stock_audit_list_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modern Trade Customer Action Bottom Sheet.
/// Matches the exact design, UX, and action flow as GT Secondary Sales CustomerActionBottomSheet.
class MtCustomerActionBottomSheet extends StatefulWidget {
  final MtOutlet outlet;

  const MtCustomerActionBottomSheet({
    super.key,
    required this.outlet,
  });

  @override
  State<MtCustomerActionBottomSheet> createState() => _MtCustomerActionBottomSheetState();
}

class _MtCustomerActionBottomSheetState extends State<MtCustomerActionBottomSheet> {
  Timer? _timer;
  Duration _duration = const Duration();
  bool _isCheckingIn = false;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ModernTradeProvider>();
    if (provider.checkedInOutletId == widget.outlet.id && provider.checkInTime != null) {
      _duration = DateTime.now().difference(provider.checkInTime!);
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final provider = context.read<ModernTradeProvider>();
      if (provider.checkedInOutletId == widget.outlet.id && provider.checkInTime != null) {
        setState(() {
          _duration = DateTime.now().difference(provider.checkInTime!);
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _makeCall() async {
    final phoneNumber = (widget.outlet.phone != null && widget.outlet.phone!.trim().isNotEmpty)
        ? widget.outlet.phone!.trim()
        : '';
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                phoneNumber.isNotEmpty
                    ? 'Could not launch dialer for $phoneNumber'
                    : 'No phone number available for ${widget.outlet.name}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching dialer: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<String?> _showJustificationDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Off-Schedule Visit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.outlet.name} is not scheduled in your PJP for today. Please provide a reason to check in.',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Emergency store replenishment request...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStrong,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('Submit & Check In'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckIn() async {
    if (_isCheckingIn || _isCheckingOut) return;
    final provider = context.read<ModernTradeProvider>();

    setState(() => _isCheckingIn = true);
    try {
      if (widget.outlet.isRecommended) {
        await provider.checkIn(outletId: widget.outlet.id);
      } else {
        final reason = await _showJustificationDialog();
        if (reason == null || reason.trim().isEmpty) {
          setState(() => _isCheckingIn = false);
          return;
        }
        await provider.checkIn(
          outletId: widget.outlet.id,
          justificationReason: reason.trim(),
        );
      }

      if (mounted) {
        _duration = const Duration();
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checked in to ${widget.outlet.name} successfully!'),
            backgroundColor: AppColors.primaryStrong,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showValidationErrorDialog(
          context,
          e.toString().replaceAll('Exception: ', ''),
          title: 'Check-in Error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingIn = false);
      }
    }
  }

  Future<void> _handleCheckOut() async {
    if (_isCheckingOut || _isCheckingIn) return;
    final provider = context.read<ModernTradeProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Check Out'),
        content: Text('Are you sure you want to check out of ${widget.outlet.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Check Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      VisitReasonSelection? selection;
      if (provider.requiresVisitReason) {
        if (!mounted) return;
        selection = await VisitReasonDialog.show(context);
        if (selection == null) return;
      }

      setState(() => _isCheckingOut = true);
      try {
        await provider.checkOut(
          visitReasonId: selection?.reasonId,
          reasonNotes: selection?.notes,
          saleAmount: selection?.saleAmount,
        );
        _timer?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Checked out of ${widget.outlet.name}'),
              backgroundColor: AppColors.primaryStrong,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          showValidationErrorDialog(
            context,
            e.toString().replaceAll('Exception: ', ''),
            title: 'Check-out Error',
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isCheckingOut = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModernTradeProvider>();
    final isCheckedIn = provider.checkedInOutletId == widget.outlet.id || widget.outlet.isActiveCheckedIn;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'MODERN TRADE OUTLET',
                          style: TextStyle(
                            color: AppColors.primaryStrong,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.outlet.isRecommended
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFF0284C7).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.outlet.isRecommended ? 'Recommended' : 'Allowed',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: widget.outlet.isRecommended
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.outlet.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.outlet.ssCode != null && widget.outlet.ssCode!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Code: ${widget.outlet.ssCode!.trim()}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (widget.outlet.street != null && widget.outlet.street!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.outlet.street!.trim(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Grid
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  Icons.shopping_cart_outlined,
                  'Orders',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SecondaryOrdersListScreen(
                          outletId: widget.outlet.id,
                          outletName: widget.outlet.name,
                          saleType: 'primary',
                          businessType: 'mt',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  Icons.inventory_2_outlined,
                  'Stock\nAudit',
                  onTap: () async {
                    final allowed = await checkAttendanceRestriction(
                      context,
                      actionName: 'Stock Audit / Outlet Visit',
                    );
                    if (!allowed || !context.mounted) return;

                    if (isCheckedIn) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MtStockAuditListScreen(
                            outletId: widget.outlet.id,
                            outletName: widget.outlet.name,
                            visitId: provider.currentVisitId,
                          ),
                        ),
                      );
                    } else {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Check-in Required'),
                          content: const Text(
                            'You must check in to the outlet before performing a Modern Trade stock audit.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _handleCheckIn();
                                if (context.mounted &&
                                    provider.checkedInOutletId == widget.outlet.id) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MtStockAuditListScreen(
                                        outletId: widget.outlet.id,
                                        outletName: widget.outlet.name,
                                        visitId: provider.currentVisitId,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Check In Now'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  Icons.phone_outlined,
                  'Call',
                  onTap: _makeCall,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  Icons.history,
                  'Visit\nHistory',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OutletVisitHistoryScreen(
                          outletId: widget.outlet.id,
                          outletName: widget.outlet.name,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (isCheckedIn)
                Expanded(
                  child: _buildActionBtn(
                    Icons.logout,
                    'Check\nOut',
                    iconColor: const Color(0xFFDC2626),
                    onTap: _handleCheckOut,
                  ),
                )
              else
                Expanded(
                  child: _buildActionBtn(
                    Icons.login,
                    'Check\nIn',
                    iconColor: const Color(0xFF10B981),
                    onTap: _handleCheckIn,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // New Order Primary Button
          ElevatedButton(
            onPressed: (_isCheckingIn || _isCheckingOut)
                ? null
                : () async {
                    final allowed = await checkAttendanceRestriction(context, actionName: 'Order Entry / Outlet Visit');
                    if (!allowed || !context.mounted) return;

                    final authProv = context.read<AuthProvider>();
                    final canSkipCheckin = authProv.session?.user.permissions?.canCreateOrderWithoutCheckin ?? false;

                    if (isCheckedIn) {
                      Navigator.pop(context); // Close bottom sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductSelectionScreen(
                            saleType: 'primary',
                            partnerId: widget.outlet.id,
                            customerName: widget.outlet.name,
                            customerCode: widget.outlet.ssCode,
                            mediumId: null,
                            visitId: provider.currentVisitId,
                            businessType: 'mt',
                          ),
                        ),
                      );
                    } else if (canSkipCheckin) {
                      final nav = Navigator.of(context);
                      final selectedMediumId = await ssShowOrderMediumDialog(
                        context,
                        customerName: widget.outlet.name,
                        customerCode: widget.outlet.ssCode,
                      );
                      if (selectedMediumId != null && mounted) {
                        nav.pop(); // Close bottom sheet
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => ProductSelectionScreen(
                              saleType: 'primary',
                              partnerId: widget.outlet.id,
                              customerName: widget.outlet.name,
                              customerCode: widget.outlet.ssCode,
                              mediumId: selectedMediumId,
                              visitId: provider.currentVisitId,
                              businessType: 'mt',
                            ),
                          ),
                        );
                      }
                    } else {
                      // Check-in required prompt
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Check-in Required'),
                          content: const Text(
                            'You must check in to the outlet before creating a Modern Trade sales order.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx); // Close dialog
                                await _handleCheckIn();
                              },
                              child: const Text('Check In Now'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStrong,
              disabledBackgroundColor: AppColors.borderSoft,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isCheckingIn
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'New Order',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // Arrival Time / Countdown
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCheckedIn ? Icons.timer_outlined : Icons.access_time,
                  color: AppColors.textSecondary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  isCheckedIn
                      ? 'Checked in: ${_formatDuration(_duration)}'
                      : 'Ready to check in',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildActionBtn(
    IconData icon,
    String label, {
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor ?? AppColors.primaryStrong, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
