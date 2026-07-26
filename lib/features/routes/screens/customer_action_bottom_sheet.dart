import 'dart:async';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/features/routes/screens/outlet_visit_history_screen.dart';
import 'package:secondary_sales/features/routes/screens/new_joint_visit_screen.dart';
import 'package:secondary_sales/features/sales/screens/order_creation_screen.dart';
import 'package:secondary_sales/features/sales/screens/out_of_geo_fence_screen.dart';
import 'package:secondary_sales/features/sales/screens/secondary_orders_list_screen.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

class CustomerActionBottomSheet extends StatefulWidget {
  final String customerName;
  final int outletId;
  final String? phone;
  final String? mobile;
  const CustomerActionBottomSheet({
    super.key,
    required this.customerName,
    required this.outletId,
    this.phone,
    this.mobile,
  });

  @override
  State<CustomerActionBottomSheet> createState() =>
      _CustomerActionBottomSheetState();
}

class _CustomerActionBottomSheetState extends State<CustomerActionBottomSheet> {
  Timer? _timer;
  Duration _duration = const Duration();

  @override
  void initState() {
    super.initState();
    final routeProv = Provider.of<RouteProvider>(context, listen: false);
    if (routeProv.checkedInOutletId == widget.outletId &&
        routeProv.checkInTime != null) {
      _duration = DateTime.now().difference(routeProv.checkInTime!);
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
      final routeProv = Provider.of<RouteProvider>(context, listen: false);
      if (routeProv.checkedInOutletId == widget.outletId &&
          routeProv.checkInTime != null) {
        setState(() {
          _duration = DateTime.now().difference(routeProv.checkInTime!);
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _makeCall() async {
    final phoneNumber = (widget.mobile != null && widget.mobile!.trim().isNotEmpty)
        ? widget.mobile!.trim()
        : (widget.phone != null && widget.phone!.trim().isNotEmpty)
            ? widget.phone!.trim()
            : '';
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
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
                    : 'No phone number available for ${widget.customerName}',
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

  @override
  Widget build(BuildContext context) {
    final routeProv = Provider.of<RouteProvider>(context);
    final isCheckedIn = routeProv.checkedInOutletId == widget.outletId;

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
                    const Text(
                      'CUSTOMER SELECTED',
                      style: TextStyle(
                        color: AppColors.primaryStrong,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.customerName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

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
                          outletId: widget.outletId,
                          outletName: widget.customerName,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionBtn(
                  Icons.phone_outlined,
                  'Call',
                  onTap: _makeCall,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionBtn(
                  Icons.history,
                  'Visit\nHistory',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OutletVisitHistoryScreen(
                          outletId: widget.outletId,
                          outletName: widget.customerName,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  Icons.handshake_outlined,
                  'Joint\nVisit',
                  onTap: () async {
                    if (!isCheckedIn) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Please check in first to start a joint visit.",
                          ),
                        ),
                      );
                      return;
                    }
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NewJointVisitScreen(
                          outletId: widget.outletId,
                          outletName: widget.customerName,
                          currentVisitId: routeProv.currentVisitId,
                        ),
                      ),
                    );
                    if (!context.mounted) return;
                    if (result == true) {
                      Navigator.pop(context); // close bottom sheet
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: const SizedBox()),
              const SizedBox(width: 12),
              Expanded(child: const SizedBox()),
            ],
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: () {
              final authProv = context.read<AuthProvider>();
              final canSkipCheckin = authProv.session?.user.permissions?.canCreateOrderWithoutCheckin ?? false;

              if (isCheckedIn) {
                Navigator.pop(context); // Close bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderCreationScreen(
                      outletId: widget.outletId,
                      customerName: widget.customerName,
                      mediumId: null, // Blank/Null medium for physical visit
                      routeId: routeProv.activeRoute?.id,
                      visitId: routeProv.currentVisitId,
                    ),
                  ),
                );
              } else if (canSkipCheckin) {
                Navigator.pop(context); // Close bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OutOfGeoFenceScreen(
                      outletId: widget.outletId,
                      customerName: widget.customerName,
                      routeId: routeProv.activeRoute?.id,
                      visitId: routeProv.currentVisitId,
                    ),
                  ),
                );
              } else {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Check-in Required'),
                    content: const Text(
                      'You must check in to the outlet before creating a secondary sales order.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx); // Close dialog
                          final employeeId = authProv.session?.user.employeeId;
                          if (employeeId != null) {
                            try {
                              await routeProv.checkIn(employeeId, widget.outletId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Checked in successfully!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Check-in failed: $e')),
                                );
                              }
                            }
                          }
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
            child: const Text(
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryStrong, size: 24),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
