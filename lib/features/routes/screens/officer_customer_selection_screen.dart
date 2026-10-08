import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
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
import 'package:secondary_sales/core/util/proximity_helper.dart';
import 'package:secondary_sales/core/util/dialog_helper.dart';
import 'package:secondary_sales/core/widgets/app_camera_capture_dialog.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/services/gps_lock_service.dart';
import 'package:secondary_sales/core/widgets/gps_status_banner.dart';

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
    extends State<OfficerCustomerSelectionScreen>
    with WidgetsBindingObserver {
  int? selectedOutletId;
  String? selectedOutletName;
  int? _checkingInOutletId;
  int? _checkingOutOutletId;
  late Future<RouteModel?> _routeFuture;
  final GpsLockService _gpsLockService = GpsLockService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final routeProv = Provider.of<RouteProvider>(
      context,
      listen: false,
    );
    _routeFuture = routeProv.fetchRouteDetail(widget.routeId);
    _startGpsMonitoring();
  }

  void _startGpsMonitoring() {
    _gpsLockService.startTracking(
      onPositionUpdate: (Position position) {
        if (mounted) {
          context.read<RouteProvider>().updateLocation(position);
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _gpsLockService.pause();
    } else if (state == AppLifecycleState.resumed) {
      _gpsLockService.resume(
        onPositionUpdate: (Position position) {
          if (mounted) {
            context.read<RouteProvider>().updateLocation(position);
          }
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsLockService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshRoute() {
    setState(() {
      _routeFuture = Provider.of<RouteProvider>(
        context,
        listen: false,
      ).fetchRouteDetail(widget.routeId);
    });
  }

  Future<void> _openActionModalFor(
    int outletId,
    String outletName, {
    String? outletCode,
    String? phone,
    String? mobile,
    double? latitude,
    double? longitude,
    double? outletRadius,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerActionBottomSheet(
        customerName: outletName,
        outletId: outletId,
        customerCode: outletCode,
        phone: phone,
        mobile: mobile,
        latitude: latitude,
        longitude: longitude,
        outletRadius: outletRadius,
      ),
    );
    if (mounted) {
      _refreshRoute();
    }
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

  Widget _buildDistanceBadge(
    double distanceMeters, {
    required RouteOutlet outlet,
    Position? userPosition,
  }) {
    final formatted = ProximityHelper.formatDistance(distanceMeters);
    return InkWell(
      onTap: () {
        ProximityHelper.openGoogleMapsDirections(
          context: context,
          destinationLat: outlet.partnerLatitude,
          destinationLng: outlet.partnerLongitude,
          originLat: userPosition?.latitude,
          originLng: userPosition?.longitude,
          destinationTitle: outlet.name,
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.near_me, size: 11, color: Color(0xFF2563EB)),
            const SizedBox(width: 3),
            Text(
              formatted,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D4ED8),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.open_in_new, size: 9.5, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20.0),
            child: CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.map, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: Consumer<RouteProvider>(
        builder: (context, routeProvider, child) {
          return FutureBuilder<RouteModel?>(
            future: _routeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading route: ${snapshot.error}'),
                );
              }

              final routeDetail = snapshot.data;
              final outlets = (routeDetail?.outlets ?? [])
                  .where((outlet) => outlet.active)
                  .toList();
              final sortedOutlets = routeProvider.getSortedRouteOutlets(
                outlets,
                searchQuery: _searchQuery,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 4.0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderSoft),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.alt_route_rounded,
                                  size: 18,
                                  color: AppColors.primaryStrong,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ROUTE',
                                      style: TextStyle(
                                        color: AppColors.primaryStrong,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.routeName,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (routeDetail?.distributorName != null &&
                              routeDetail!.distributorName!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: AppColors.borderMuted),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.business_outlined,
                                  size: 15,
                                  color: Color(0xFF0D9488),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Distributor (DB): ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    routeDetail.distributorName!,
                                    style: const TextStyle(
                                      color: Color(0xFF1E293B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Non-intrusive GPS Satellite Lock Status Banner
                  GpsStatusBanner(
                    lockStateNotifier: _gpsLockService.stateNotifier,
                    onRefresh: _startGpsMonitoring,
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 6.0, 20.0, 8.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by Code, Name, Phone, Owner...',
                        hintStyle: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
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
                  // Proximity & GPS Toolbar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
                    child: Row(
                      children: [
                        // Sort Nearest Toggle Button
                        InkWell(
                          onTap: () {
                            routeProvider.toggleSortByNearest();
                            if (routeProvider.sortByNearest && routeProvider.currentPosition == null) {
                              routeProvider.refreshGpsPosition(requireFresh: false);
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: routeProvider.sortByNearest
                                  ? AppColors.primaryStrong
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: routeProvider.sortByNearest
                                    ? AppColors.primaryStrong
                                    : AppColors.borderSoft,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me,
                                  size: 14,
                                  color: routeProvider.sortByNearest
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  routeProvider.sortByNearest ? 'Nearest First' : 'Sequence Order',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: routeProvider.sortByNearest
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Refresh GPS Button
                        InkWell(
                          onTap: routeProvider.isGpsRefreshing
                              ? null
                              : () async {
                                  final pos = await routeProvider.refreshGpsPosition(requireFresh: true);
                                  if (pos != null && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('GPS location updated.'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.borderSoft),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (routeProvider.isGpsRefreshing)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  const Icon(
                                    Icons.my_location,
                                    size: 14,
                                    color: AppColors.primaryStrong,
                                  ),
                                const SizedBox(width: 5),
                                Text(
                                  routeProvider.isGpsRefreshing ? 'Updating...' : 'Refresh GPS',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryStrong,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'AVAILABLE OUTLETS (${outlets.length})'
                          : 'FOUND OUTLETS (${sortedOutlets.length})',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (sortedOutlets.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No outlets assigned to this route.'
                              : 'No outlets match "$_searchQuery".',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          kSsFabScrollPadding,
                        ),
                        itemCount: sortedOutlets.length,
                        itemBuilder: (context, index) {
                          final outlet = sortedOutlets[index];
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

                          final distanceMeters = ProximityHelper.calculateDistance(
                            userLat: routeProv.currentPosition?.latitude,
                            userLng: routeProv.currentPosition?.longitude,
                            outletLat: outlet.partnerLatitude,
                            outletLng: outlet.partnerLongitude,
                          );

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _openActionModalFor(
                                outlet.id,
                                outlet.name,
                                outletCode: outlet.code,
                                phone: outlet.phone,
                                mobile: outlet.mobile,
                                latitude: outlet.partnerLatitude,
                                longitude: outlet.partnerLongitude,
                                outletRadius: outlet.outletRadius,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.storefront,
                                      color: Color(0xFF3B82F6),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Primary: Outlet Name with full column width
                                        Text(
                                          outlet.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            height: 1.25,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        // Secondary: SS Code + Distance Badge on their own row
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            if (outlet.code != null &&
                                                outlet.code!.trim().isNotEmpty) ...[
                                              Flexible(
                                                child: Text(
                                                  'SS Code: ${outlet.code!.trim()}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              if (distanceMeters != null) const SizedBox(width: 6),
                                            ],
                                            if (distanceMeters != null)
                                              _buildDistanceBadge(
                                                distanceMeters,
                                                outlet: outlet,
                                                userPosition: routeProvider.currentPosition,
                                              ),
                                          ],
                                        ),
                                        if (outlet.ownerName != null &&
                                            outlet.ownerName!.trim().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Owner: ${outlet.ownerName!.trim()}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                        if ((outlet.mobile != null &&
                                                outlet.mobile!.trim().isNotEmpty) ||
                                            (outlet.phone != null &&
                                                outlet.phone!.trim().isNotEmpty)) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Phone: ${outlet.mobile ?? outlet.phone}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 3),
                                        Text(
                                          outlet.street ??
                                              'No address provided',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (isCheckedIn) ...[
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF10B981),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  routeProv.checkInTime != null
                                                      ? 'Checked In at ${_formatTime(routeProv.checkInTime!)}'
                                                      : 'Checked In',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Color(0xFF10B981),
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else if (isCheckedOut) ...[
                                          const SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: const BoxDecoration(
                                                  color:
                                                      AppColors.textSecondary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              const Expanded(
                                                child: Text(
                                                  'Checked Out',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
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
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFDC2626,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
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
                                                 showValidationErrorDialog(
                                                   context,
                                                   'You are already checked in at another outlet. Please check out before checking in to "${outlet.name}".',
                                                   title: 'Active Check-in Exists',
                                                 );
                                                 return;
                                               }
                                               setState(() => _checkingInOutletId = outlet.id);
                                               try {
                                                  // 1. Acquire GPS position with fast-converging resolver (re-using fresh route position if available)
                                                  Position? position;
                                                  final routeProv = context.read<RouteProvider>();
                                                  try {
                                                    position = await LocationService.resolveCheckInPosition(
                                                      cachedPosition: routeProv.currentPosition,
                                                      desiredAccuracy: 25.0,
                                                      maxAcceptableAccuracy: 70.0,
                                                      burstTimeout: const Duration(seconds: 4),
                                                    );
                                                  } catch (e) {
                                                    if (!auth.canSkipAttendanceGeo) {
                                                      rethrow;
                                                    }
                                                  }

                                                  // 2. Validate Geofence FIRST before letting user take a photo
                                                  if (!auth.canSkipAttendanceGeo &&
                                                      outlet.partnerLatitude != null &&
                                                      outlet.partnerLongitude != null &&
                                                      outlet.partnerLatitude != 0.0 &&
                                                      outlet.partnerLongitude != 0.0 &&
                                                      position != null) {
                                                    final double distanceMeters = Geolocator.distanceBetween(
                                                      position.latitude,
                                                      position.longitude,
                                                      outlet.partnerLatitude!,
                                                      outlet.partnerLongitude!,
                                                    );
                                                    final double allowedRadius = outlet.outletRadius ?? 50.0;
                                                    if (!ProximityHelper.isGeofenceSatisfied(
                                                      distanceMeters: distanceMeters,
                                                      accuracyMeters: position.accuracy,
                                                      allowedRadius: allowedRadius,
                                                    )) {
                                                      throw Exception(
                                                        'You are ${distanceMeters.round()}m away from "${outlet.name}". Allowed radius is ${allowedRadius.round()}m (GPS accuracy: ±${position.accuracy.round()}m).',
                                                      );
                                                    }
                                                  }

                                                  String? imageB64;
                                                  if (auth.canView(AppScreen.newJointVisit)) {
                                                    final XFile? photo = await AppCameraCaptureDialog.capture(
                                                      context,
                                                      title: 'Joint Visit Check-in',
                                                      helperTip: 'Take a check-in photo with the outlet owner',
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
                                                    final persistentFile = await MediaStorageService.persistPickedFile(
                                                      photo,
                                                      category: MediaCategory.visits,
                                                      customPrefix: 'joint_visit',
                                                    );
                                                    final bytes = persistentFile != null
                                                        ? await persistentFile.readAsBytes()
                                                        : await photo.readAsBytes();
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
                                                     phone: outlet.phone,
                                                     mobile: outlet.mobile,
                                                     latitude: outlet.partnerLatitude,
                                                     longitude: outlet.partnerLongitude,
                                                     outletRadius: outlet.outletRadius,
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
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF059669,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
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
                                      routeDetail?.distributorName ??
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
