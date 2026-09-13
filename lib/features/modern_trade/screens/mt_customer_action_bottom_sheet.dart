import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/services/location_service.dart';
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
import 'package:secondary_sales/features/modern_trade/screens/mt_stock_audit_create_screen.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_stock_audit_list_screen.dart';
import 'package:secondary_sales/core/util/proximity_helper.dart';
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

  Future<bool> _handleCheckIn() async {
    if (_isCheckingIn || _isCheckingOut) return false;
    final provider = context.read<ModernTradeProvider>();

    // 0. Prevent concurrent check-ins: if user is already checked in to another outlet
    if (provider.checkedInOutletId != null && provider.checkedInOutletId != widget.outlet.id) {
      final currentOutletName = provider.outlets
          .where((o) => o.id == provider.checkedInOutletId)
          .map((o) => o.name)
          .firstOrNull ?? 'another outlet';
      showValidationErrorDialog(
        context,
        'You are currently checked in at "$currentOutletName". You must check out from "$currentOutletName" before checking in to "${widget.outlet.name}".',
        title: 'Active Check-in Exists',
      );
      return false;
    }

    // 0.1 If already checked in to THIS outlet
    if (provider.checkedInOutletId == widget.outlet.id || widget.outlet.isActiveCheckedIn) {
      showValidationErrorDialog(
        context,
        'You are already checked in to "${widget.outlet.name}".',
        title: 'Already Checked In',
      );
      return false;
    }

    setState(() => _isCheckingIn = true);
    try {
      // 1. Acquire GPS position FIRST
      final position = await LocationService.getCurrentPosition(
        requireFresh: true,
        timeLimit: const Duration(seconds: 15),
      );

      // 2. Validate Geofence FIRST before opening any justification request popup
      if (widget.outlet.latitude != null &&
          widget.outlet.longitude != null &&
          widget.outlet.latitude != 0.0 &&
          widget.outlet.longitude != 0.0) {
        final double distanceMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          widget.outlet.latitude!,
          widget.outlet.longitude!,
        );
        final double allowedRadius = widget.outlet.outletRadius ?? 50.0;
        if (distanceMeters > allowedRadius) {
          throw Exception(
            'You are ${distanceMeters.round()}m away from "${widget.outlet.name}". Allowed radius is ${allowedRadius.round()}m.',
          );
        }
      }

      // 3. Location is valid! If recommended proceed, else prompt for justification
      if (widget.outlet.isRecommended) {
        await provider.checkIn(
          outletId: widget.outlet.id,
          position: position,
        );
      } else {
        final reason = await _showJustificationDialog();
        if (reason == null || reason.trim().isEmpty) {
          return false;
        }
        await provider.checkIn(
          outletId: widget.outlet.id,
          justificationReason: reason.trim(),
          position: position,
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
        return true;
      }
      return false;
    } catch (e) {
      if (mounted) {
        showValidationErrorDialog(
          context,
          e.toString().replaceAll('Exception: ', ''),
          title: 'Check-in Error',
        );
      }
      return false;
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

  Future<void> _handleStockAuditAction({bool directCreate = false}) async {
    final allowed = await checkAttendanceRestriction(
      context,
      actionName: 'Stock Audit / Outlet Visit',
    );
    if (!allowed || !mounted) return;

    final provider = context.read<ModernTradeProvider>();
    final isCheckedIn = provider.checkedInOutletId == widget.outlet.id || widget.outlet.isActiveCheckedIn;

    if (isCheckedIn) {
      if (directCreate) {
        Navigator.pop(context); // Close bottom sheet
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MtStockAuditCreateScreen(
              outletId: widget.outlet.id,
              outletName: widget.outlet.name,
              visitId: provider.currentVisitId,
            ),
          ),
        );
      } else {
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
    } else {
      if (!mounted) return;
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
                final checkedIn = await _handleCheckIn();
                if (checkedIn && mounted) {
                  if (directCreate) {
                    Navigator.pop(context);
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MtStockAuditCreateScreen(
                          outletId: widget.outlet.id,
                          outletName: widget.outlet.name,
                          visitId: provider.currentVisitId,
                        ),
                      ),
                    );
                  } else {
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
                }
              },
              child: const Text('Check In Now'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleNewOrderAction() async {
    final allowed = await checkAttendanceRestriction(
      context,
      actionName: 'Order Entry / Outlet Visit',
    );
    if (!allowed || !mounted) return;

    final provider = context.read<ModernTradeProvider>();
    final isCheckedIn = provider.checkedInOutletId == widget.outlet.id || widget.outlet.isActiveCheckedIn;
    final authProv = context.read<AuthProvider>();
    final canSkipCheckin = authProv.session?.user.permissions?.canCreateOrderWithoutCheckin ?? false;

    if (isCheckedIn) {
      Navigator.pop(context); // Close bottom sheet
      if (!mounted) return;
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
      if (!mounted) return;
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
  }

  Widget _buildBottomCta({
    required bool canCreateOrder,
    required bool canCreateAudit,
  }) {
    if (canCreateOrder && canCreateAudit) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: (_isCheckingIn || _isCheckingOut)
                  ? null
                  : () => _handleStockAuditAction(directCreate: true),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryStrong, width: 1.5),
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryStrong, size: 20),
              label: const Text(
                'Stock Audit',
                style: TextStyle(
                  color: AppColors.primaryStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: (_isCheckingIn || _isCheckingOut)
                  ? null
                  : _handleNewOrderAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryStrong,
                disabledBackgroundColor: AppColors.borderSoft,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 20),
              label: const Text(
                'New Order',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (canCreateOrder) {
      return ElevatedButton.icon(
        onPressed: (_isCheckingIn || _isCheckingOut)
            ? null
            : _handleNewOrderAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryStrong,
          disabledBackgroundColor: AppColors.borderSoft,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _isCheckingIn
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.add_shopping_cart, color: Colors.white, size: 20),
        label: const Text(
          'New Order',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (canCreateAudit) {
      return ElevatedButton.icon(
        onPressed: (_isCheckingIn || _isCheckingOut)
            ? null
            : () => _handleStockAuditAction(directCreate: true),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryStrong,
          disabledBackgroundColor: AppColors.borderSoft,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _isCheckingIn
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
        label: const Text(
          'New Stock Audit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModernTradeProvider>();
    final isCheckedIn = provider.checkedInOutletId == widget.outlet.id || widget.outlet.isActiveCheckedIn;

    final auth = context.watch<AuthProvider>();
    final canAccessPrimary = auth.canAccessMtPrimarySales;
    final canAccessSecondary = auth.canAccessMtSecondarySales;

    final canViewOrders = canAccessPrimary && auth.canView(AppScreen.mtOrdersList);
    final canViewStockAudits = canAccessSecondary && auth.canView(AppScreen.mtSecStockAuditsList);

    final canCreateOrder = canAccessPrimary && auth.canDo(AppAction.mtOrderCreate);
    final canCreateAudit = canAccessSecondary && auth.canDo(AppAction.mtSecStockAuditCreate);

    final actionButtons = <Widget>[];

    if (canViewOrders) {
      actionButtons.add(
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
      );
    }

    if (canViewStockAudits) {
      actionButtons.add(
        Expanded(
          child: _buildActionBtn(
            Icons.inventory_2_outlined,
            'Stock\nAudit',
            onTap: () => _handleStockAuditAction(directCreate: false),
          ),
        ),
      );
    }

    actionButtons.add(
      Expanded(
        child: _buildActionBtn(
          Icons.directions_outlined,
          'Directions',
          onTap: () {
            ProximityHelper.openGoogleMapsDirections(
              context: context,
              destinationLat: widget.outlet.latitude,
              destinationLng: widget.outlet.longitude,
              originLat: provider.currentPosition?.latitude,
              originLng: provider.currentPosition?.longitude,
              destinationTitle: widget.outlet.name,
            );
          },
        ),
      ),
    );

    actionButtons.add(
      Expanded(
        child: _buildActionBtn(
          Icons.phone_outlined,
          'Call',
          onTap: _makeCall,
        ),
      ),
    );

    actionButtons.add(
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
    );

    if (isCheckedIn) {
      actionButtons.add(
        Expanded(
          child: _buildActionBtn(
            Icons.logout,
            'Check\nOut',
            iconColor: const Color(0xFFDC2626),
            onTap: _handleCheckOut,
          ),
        ),
      );
    } else {
      actionButtons.add(
        Expanded(
          child: _buildActionBtn(
            Icons.login,
            'Check\nIn',
            iconColor: const Color(0xFF10B981),
            onTap: _handleCheckIn,
          ),
        ),
      );
    }

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
              for (int i = 0; i < actionButtons.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                actionButtons[i],
              ],
            ],
          ),

          if (canCreateOrder || canCreateAudit) ...[
            const SizedBox(height: 24),
            _buildBottomCta(
              canCreateOrder: canCreateOrder,
              canCreateAudit: canCreateAudit,
            ),
          ],

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
