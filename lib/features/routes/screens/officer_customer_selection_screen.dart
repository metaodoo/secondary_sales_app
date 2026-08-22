import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/data/models/routes/visit_reason.dart';
import 'package:secondary_sales/features/routes/screens/visit_reason_dialog.dart';
import 'package:secondary_sales/data/models/routes/route.dart';
import 'package:secondary_sales/features/routes/screens/customer_action_bottom_sheet.dart';
import 'package:secondary_sales/features/routes/screens/create_outlet_screen.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:secondary_sales/core/services/location_service.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class OfficerCustomerSelectionScreen extends StatefulWidget {
  final int routeId;
  final String routeName;
  const OfficerCustomerSelectionScreen({
    super.key,
    required this.routeId,
    required this.routeName,
  });

  @override
  State<OfficerCustomerSelectionScreen> createState() =>
      _OfficerCustomerSelectionScreenState();
}

class _OfficerCustomerSelectionScreenState
    extends State<OfficerCustomerSelectionScreen> {
  int? selectedOutletId;
  String? selectedOutletName;
  int? _checkingInOutletId;
  int? _checkingOutOutletId;
  late Future<RouteModel?> _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = Provider.of<RouteProvider>(
      context,
      listen: false,
    ).fetchRouteDetail(widget.routeId);
  }

  void _openActionModalFor(
    int outletId,
    String outletName, {
    String? outletCode,
    String? phone,
    String? mobile,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerActionBottomSheet(
        customerName: outletName,
        outletId: outletId,
        customerCode: outletCode,
        phone: phone,
        mobile: mobile,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final localDt = dt.toLocal();
    final hour = localDt.hour > 12
        ? localDt.hour - 12
        : (localDt.hour == 0 ? 12 : localDt.hour);
    final min = localDt.minute.toString().padLeft(2, '0');
    final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.routeName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ProfileAvatar(),
          ),
        ],
      ),
      body: FutureBuilder<RouteModel?>(
        future: _routeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final routeModel = snapshot.data;

          return Consumer<RouteProvider>(
            builder: (context, routeProvider, child) {
              if (routeProvider.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Backend Error: ${routeProvider.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final outlets = routeModel?.outlets ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Find an outlet...',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'AVAILABLE OUTLETS',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (outlets.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No outlets assigned to this route.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: outlets.length,
                        itemBuilder: (context, index) {
                          final outlet = outlets[index];
                          final routeProv = routeProvider;
                          final auth = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final employeeId = auth.employeeId;

                          final isCheckedIn =
                              routeProv.checkedInOutletId == outlet.id;

                          final isCheckedOut = routeProv.checkedOutOutletIds
                              .contains(outlet.id);

                          return GestureDetector(
                            onTap: () {
                              _openActionModalFor(
                                outlet.id,
                                outlet.name,
                                phone: outlet.phone,
                                mobile: outlet.mobile,
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCheckedIn
                                      ? const Color(0xFF10B981)
                                      : AppColors.borderSoft,
                                  width: isCheckedIn ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Icon(
                                      Icons.storefront,
                                      color: Color(0xFF3B82F6),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          outlet.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (outlet.code != null &&
                                            outlet.code!.trim().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Code: ${outlet.code!.trim()}',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          outlet.street ??
                                              'No address provided',
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (isCheckedIn) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF10B981),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                routeProv.checkInTime != null
                                                    ? 'Checked In at ${_formatTime(routeProv.checkInTime!)}'
                                                    : 'Checked In',
                                                style: const TextStyle(
                                                  color: Color(0xFF10B981),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else if (isCheckedOut) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color:
                                                      AppColors.textSecondary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                'Checked Out',
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (isCheckedIn) ...[
                                    ElevatedButton.icon(
                                      onPressed: _checkingOutOutletId != null
                                           ? null
                                           : () async {
                                               final confirm = await showDialog<bool>(
                                                 context: context,
                                                 builder: (ctx) => AlertDialog(
                                                   title: const Text('Check Out'),
                                                   content: Text('Are you sure you want to check out from ${outlet.name}?'),
                                                   actions: [
                                                     TextButton(
                                                       onPressed: () => Navigator.pop(ctx, false),
                                                       child: const Text('Cancel'),
                                                     ),
                                                     ElevatedButton(
                                                       onPressed: () => Navigator.pop(ctx, true),
                                                       child: const Text('Check Out'),
                                                     ),
                                                   ],
                                                 ),
                                               );
                                               if (confirm == true) {
                                                 VisitReasonSelection? selection;
                                                 if (routeProv.requiresVisitReason) {
                                                   if (!context.mounted) return;
                                                   selection =
                                                       await VisitReasonDialog.show(
                                                         context,
                                                       );
                                                   if (selection == null) return;
                                                 }
                                                 setState(() => _checkingOutOutletId = outlet.id);
                                                 try {
                                                   await routeProv.checkOut(
                                                     visitReasonId:
                                                         selection?.reasonId,
                                                     reasonNotes: selection?.notes,
                                                     saleAmount: selection?.saleAmount,
                                                   );
                                                 } catch (e) {
                                                   if (context.mounted) {
                                                     ScaffoldMessenger.of(
                                                       context,
                                                     ).showSnackBar(
                                                       SnackBar(
                                                         content: Text(
                                                           'Check-out failed: ${e.toString().replaceAll('Exception: ', '')}',
                                                         ),
                                                       ),
                                                     );
                                                   }
                                                 } finally {
                                                   if (mounted) {
                                                     setState(() => _checkingOutOutletId = null);
                                                   }
                                                 }
                                               }
                                             },
                                      icon: _checkingOutOutletId == outlet.id
                                           ? const SizedBox(
                                               width: 14,
                                               height: 14,
                                               child: CircularProgressIndicator(
                                                 strokeWidth: 2,
                                                 color: Colors.white,
                                               ),
                                             )
                                           : const Icon(
                                               Icons.logout_rounded,
                                               size: 14,
                                             ),
                                      label: const Text(
                                        'Check Out',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFDC2626,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        elevation: 2,
                                        shadowColor: const Color(
                                          0xFFDC2626,
                                        ).withOpacity(0.3),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    ElevatedButton.icon(
                                       onPressed: _checkingInOutletId != null
                                           ? null
                                           : () async {
                                               if (employeeId == null) return;
                                               if (routeProv.checkedInOutletId != null &&
                                                   routeProv.checkedInOutletId != outlet.id) {
                                                 ScaffoldMessenger.of(
                                                   context,
                                                 ).showSnackBar(
                                                   const SnackBar(
                                                     content: Text(
                                                       'Please check out from current outlet first',
                                                     ),
                                                   ),
                                                 );
                                                 return;
                                               }
                                               setState(() => _checkingInOutletId = outlet.id);
                                               try {
                                                  // 1. Acquire GPS position FIRST
                                                  final position = await LocationService.getCurrentPosition(
                                                    requireFresh: true,
                                                    timeLimit: const Duration(seconds: 15),
                                                  );

                                                  // 2. Validate Geofence FIRST before letting user take a photo
                                                  if (outlet.partnerLatitude != null &&
                                                      outlet.partnerLongitude != null &&
                                                      outlet.partnerLatitude != 0.0 &&
                                                      outlet.partnerLongitude != 0.0) {
                                                    final double distanceMeters = Geolocator.distanceBetween(
                                                      position.latitude,
                                                      position.longitude,
                                                      outlet.partnerLatitude!,
                                                      outlet.partnerLongitude!,
                                                    );
                                                    final double allowedRadius = outlet.outletRadius ?? 50.0;
                                                    if (distanceMeters > allowedRadius) {
                                                      throw Exception(
                                                        'You are ${distanceMeters.round()}m away from "${outlet.name}". Allowed radius is ${allowedRadius.round()}m.',
                                                      );
                                                    }
                                                  }

                                                  String? imageB64;
                                                  if (auth.canView(AppScreen.newJointVisit)) {
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
                                                   outlet.id,
                                                   position: position,
                                                   image1920: imageB64,
                                                 );
                                                 if (context.mounted) {
                                                    _openActionModalFor(
                                                      outlet.id,
                                                      outlet.name,
                                                      outletCode: outlet.code,
                                                    );
                                                 }
                                               } catch (e) {
                                                 if (context.mounted) {
                                                   ssShowLocationErrorDialog(
                                                     context,
                                                     e.toString().replaceAll(
                                                       'Exception: ',
                                                       '',
                                                     ),
                                                   );
                                                 }
                                               } finally {
                                                 if (mounted) {
                                                   setState(() => _checkingInOutletId = null);
                                                 }
                                               }
                                             },
                                      icon: _checkingInOutletId == outlet.id
                                           ? const SizedBox(
                                               width: 14,
                                               height: 14,
                                               child: CircularProgressIndicator(
                                                 strokeWidth: 2,
                                                 color: Colors.white,
                                               ),
                                             )
                                           : const Icon(
                                               Icons.location_on_rounded,
                                               size: 14,
                                             ),
                                      label: const Text(
                                        'Check In',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF059669,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        elevation: 2,
                                        shadowColor: const Color(
                                          0xFF059669,
                                        ).withOpacity(0.35),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            final created = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateOutletScreen(
                                  routeId: widget.routeId,
                                  routeName: widget.routeName,
                                  distributorName:
                                      routeModel?.distributorName ??
                                      'Unassigned',
                                ),
                              ),
                            );
                            if (created == true) {
                              setState(() {
                                _routeFuture = Provider.of<RouteProvider>(
                                  context,
                                  listen: false,
                                ).fetchRouteDetail(widget.routeId);
                              });
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryStrong,
                            side: const BorderSide(
                              color: AppColors.primaryStrong,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Create New Outlet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.person_add_alt_1_outlined, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
