import 'dart:async';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:secondary_sales/core/services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/features/routes/screens/outlet_visit_history_screen.dart';
import 'package:secondary_sales/features/routes/screens/new_joint_visit_screen.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/data/models/sales/order_line_entry.dart';
import 'package:secondary_sales/features/sales/screens/order_creation_screen.dart';
import 'package:secondary_sales/features/sales/screens/out_of_geo_fence_screen.dart';
import 'package:secondary_sales/features/sales/screens/product_selection_screen.dart';
import 'package:secondary_sales/features/sales/screens/secondary_orders_list_screen.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

class CustomerActionBottomSheet extends StatefulWidget {
  final String customerName;
  final int outletId;
  final String? customerCode;
  final String? phone;
  final String? mobile;
  const CustomerActionBottomSheet({
    super.key,
    required this.customerName,
    required this.outletId,
    this.customerCode,
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
  bool _isCheckingIn = false;

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
    final phoneNumber =
        (widget.mobile != null && widget.mobile!.trim().isNotEmpty)
        ? widget.mobile!.trim()
        : (widget.phone != null && widget.phone!.trim().isNotEmpty)
        ? widget.phone!.trim()
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
                    : 'No phone number available for ${widget.customerName}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error launching dialer: $e')));
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
                    if (widget.customerCode != null &&
                        widget.customerCode!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${widget.customerCode!.trim()}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
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
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: () async {
              final authProv = context.read<AuthProvider>();
              final canSkipCheckin =
                  authProv
                      .session
                      ?.user
                      .permissions
                      ?.canCreateOrderWithoutCheckin ??
                  false;

              if (isCheckedIn) {
                Navigator.pop(context); // Close bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductSelectionScreen(
                      saleType: 'secondary',
                      partnerId: widget.outletId,
                      customerName: widget.customerName,
                      customerCode: widget.customerCode,
                      mediumId: null,
                      routeId: routeProv.activeRoute?.id,
                      visitId: routeProv.currentVisitId,
                    ),
                  ),
                );
              } else if (canSkipCheckin) {
                final nav = Navigator.of(context);
                final selectedMediumId = await ssShowOrderMediumDialog(
                  context,
                  customerName: widget.customerName,
                  customerCode: widget.customerCode,
                );
                if (selectedMediumId != null) {
                  nav.pop(); // Close bottom sheet
                  nav.push(
                    MaterialPageRoute(
                      builder: (_) => ProductSelectionScreen(
                        saleType: 'secondary',
                        partnerId: widget.outletId,
                        customerName: widget.customerName,
                        customerCode: widget.customerCode,
                        mediumId: selectedMediumId,
                        routeId: routeProv.activeRoute?.id,
                        visitId: routeProv.currentVisitId,
                      ),
                    ),
                  );
                }
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
                        onPressed: _isCheckingIn
                            ? null
                            : () async {
                                Navigator.pop(ctx); // Close dialog
                                final employeeId =
                                    authProv.session?.user.employeeId;
                                if (employeeId != null) {
                                  if (mounted)
                                    setState(() => _isCheckingIn = true);
                                  try {
                                    final position = await LocationService.getCurrentPosition(
                                      requireFresh: true,
                                      timeLimit: const Duration(seconds: 15),
                                    );

                                    String? imageB64;
                                    if (authProv.canView(AppScreen.newJointVisit)) {
                                      final ImagePicker picker = ImagePicker();
                                      final XFile? photo = await picker.pickImage(
                                        source: ImageSource.camera,
                                        imageQuality: 70,
                                        maxWidth: 1024,
                                        maxHeight: 1024,
                                      );
                                      if (photo == null) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('A check-in photo is required for joint visits.'),
                                            ),
                                          );
                                        }
                                        return;
                                      }
                                      final bytes = await photo.readAsBytes();
                                      imageB64 = base64Encode(bytes);
                                    }

                                    await routeProv.checkIn(
                                      employeeId,
                                      widget.outletId,
                                      position: position,
                                      image1920: imageB64,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Checked in successfully!',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Check-in failed: $e'),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted)
                                      setState(() => _isCheckingIn = false);
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

Future<int?> ssShowOrderMediumDialog(
  BuildContext context, {
  required String customerName,
  String? customerCode,
}) async {
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      int? selectedId;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEDF0FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phonelink_ring_rounded,
                          color: AppColors.primaryStrong,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Order Medium',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              customerCode != null && customerCode.trim().isNotEmpty
                                  ? '$customerName (${customerCode.trim()})'
                                  : customerName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx, null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You are creating an order without check-in. Please select how this order was received:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: ApiService.instance.getMediums(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final mediums = snapshot.data ?? [];
                      if (mediums.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No order mediums available.'),
                        );
                      }
                      if (selectedId == null && mediums.isNotEmpty) {
                        selectedId = mediums.first['id'] as int?;
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: mediums.map((m) {
                          final id = m['id'] as int;
                          final name = m['name'] as String? ?? 'Medium';
                          final isSelected = selectedId == id;
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedId = id;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryStrong : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryStrong : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: selectedId == null
                          ? null
                          : () => Navigator.pop(ctx, selectedId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryStrong,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Proceed to Order',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
