import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/core/services/location_service.dart';
import 'package:secondary_sales/core/util/proximity_helper.dart';
import 'package:secondary_sales/core/util/parse.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/util/dialog_helper.dart';

class OutletSelectionScreen extends StatefulWidget {
  final int routeId;
  final int visitId;

  const OutletSelectionScreen({
    super.key,
    required this.routeId,
    required this.visitId,
  });

  @override
  State<OutletSelectionScreen> createState() => _OutletSelectionScreenState();
}

class _OutletSelectionScreenState extends State<OutletSelectionScreen> {
  final ApiService _apiService = ApiService.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _outlets = [];
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isInit = false;
  StreamSubscription<Position>? _positionStreamSub;
  Position? _currentPosition;
  bool _sortByNearest = false;
  bool _isGpsRefreshing = false;

  @override
  void initState() {
    super.initState();
    _startLocationStream();
    _refreshGpsPosition(requireFresh: false);
  }

  void _startLocationStream() {
    try {
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen(
        (Position position) {
          if (mounted) {
            setState(() {
              _currentPosition = position;
            });
          }
        },
        onError: (e) {
          debugPrint('Location stream error in OutletSelectionScreen: $e');
        },
      );
    } catch (e) {
      debugPrint('Could not initialize location stream: $e');
    }
  }

  Future<void> _refreshGpsPosition({bool requireFresh = false}) async {
    setState(() => _isGpsRefreshing = true);
    try {
      final pos = await LocationService.getCurrentPosition(
        requireFresh: requireFresh,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
      }
    } catch (e) {
      debugPrint('Error getting GPS in OutletSelectionScreen: $e');
    } finally {
      if (mounted) {
        setState(() => _isGpsRefreshing = false);
      }
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final auth = context.read<AuthProvider>();
      _apiService.updateAccessToken(auth.accessToken);
      _apiService.updateSessionId(auth.sessionId);
      _apiService.updateEmployeeId(auth.employeeId);
      _fetchOutlets();
      _isInit = true;
    }
  }

  Future<void> _fetchOutlets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // You can filter by route_id if backend supports it, or just fetch all
      final outlets = await _apiService.getOutlets(routeId: widget.routeId);
      setState(() {
        _outlets = outlets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIn(int outletId) async {
    final allowed = await checkAttendanceRestriction(context, actionName: 'Outlet Check-In');
    if (!allowed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final position = await LocationService.getCurrentPosition();

      if (!mounted) return;

      await _apiService.executeRouteVisitAction(
        visitId: widget.visitId,
        action: 'check_in',
        outletId: outletId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ssShowLocationErrorDialog(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _skipOutlet(int outletId) async {
    final noteController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Outlet'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(hintText: 'Reason for skipping...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, noteController.text),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await _apiService.executeRouteVisitAction(
          visitId: widget.visitId,
          action: 'skip',
          outletId: outletId,
          note: result,
        );
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to skip: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showActionDialog(Map<String, dynamic> outlet) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  outlet['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _checkIn(outlet['id']);
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Check In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryStrong,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _skipOutlet(outlet['id']);
                  },
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Skip Outlet'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDistanceBadge(
    double distanceMeters, {
    required double? lat,
    required double? lng,
    String? outletName,
  }) {
    final formatted = ProximityHelper.formatDistance(distanceMeters);
    return InkWell(
      onTap: () {
        ProximityHelper.openGoogleMapsDirections(
          context: context,
          destinationLat: lat,
          destinationLng: lng,
          originLat: _currentPosition?.latitude,
          originLng: _currentPosition?.longitude,
          destinationTitle: outletName,
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
    List<Map<String, dynamic>> displayedOutlets = _outlets.where((outlet) {
      if (outlet['active'] == false) return false;
      if (_searchQuery.isEmpty) return true;
      final code = (outlet['ss_code'] ?? outlet['code'] ?? '').toString().toLowerCase();
      final name = (outlet['name'] ?? '').toString().toLowerCase();
      final phone = (outlet['phone'] ?? '').toString().toLowerCase();
      final mobile = (outlet['mobile'] ?? '').toString().toLowerCase();
      final ownerName = (outlet['owner_name'] ?? outlet['ownerName'] ?? '').toString().toLowerCase();

      return code.contains(_searchQuery) ||
          name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          mobile.contains(_searchQuery) ||
          ownerName.contains(_searchQuery);
    }).toList();

    if (_sortByNearest && _currentPosition != null) {
      final userLat = _currentPosition!.latitude;
      final userLng = _currentPosition!.longitude;

      final withDistance = <MapEntry<Map<String, dynamic>, double>>[];
      final withoutCoords = <Map<String, dynamic>>[];

      for (final o in displayedOutlets) {
        final lat = o['partner_latitude'] != null
            ? asDouble(o['partner_latitude'])
            : (o['latitude'] != null ? asDouble(o['latitude']) : null);
        final lng = o['partner_longitude'] != null
            ? asDouble(o['partner_longitude'])
            : (o['longitude'] != null ? asDouble(o['longitude']) : null);

        final d = ProximityHelper.calculateDistance(
          userLat: userLat,
          userLng: userLng,
          outletLat: lat,
          outletLng: lng,
        );
        if (d != null) {
          withDistance.add(MapEntry(o, d));
        } else {
          withoutCoords.add(o);
        }
      }

      withDistance.sort((a, b) => a.value.compareTo(b.value));
      displayedOutlets = [
        ...withDistance.map((e) => e.key),
        ...withoutCoords,
      ];
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          BlueHeader(
            title: 'Select Outlet',
            subtitle: 'Choose an outlet to visit',
            trailing: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              decoration: ssInputDecoration(
                'Search by Code, Name, Phone, Owner...',
                Icons.search,
              ).copyWith(
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
              ),
            ),
          ),
          // Proximity & GPS Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                // Sort Nearest Toggle Button
                InkWell(
                  onTap: () {
                    setState(() {
                      _sortByNearest = !_sortByNearest;
                    });
                    if (_sortByNearest && _currentPosition == null) {
                      _refreshGpsPosition(requireFresh: false);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _sortByNearest
                          ? AppColors.primaryStrong
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _sortByNearest
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
                          color: _sortByNearest
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sortByNearest ? 'Nearest First' : 'Default Order',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _sortByNearest
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
                  onTap: _isGpsRefreshing
                      ? null
                      : () async {
                          await _refreshGpsPosition(requireFresh: true);
                          if (mounted && _currentPosition != null) {
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
                        if (_isGpsRefreshing)
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
                          _isGpsRefreshing ? 'Updating...' : 'Refresh GPS',
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
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          else ...[
            Expanded(
              child: displayedOutlets.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No outlets found for this route.'
                            : 'No outlets match "$_searchQuery".',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: displayedOutlets.length,
                      itemBuilder: (context, index) {
                        final outlet = displayedOutlets[index];
                        final code = outlet['ss_code'] ?? outlet['code'];
                        final owner = outlet['owner_name'] ?? outlet['ownerName'];
                        final phone = outlet['mobile'] ?? outlet['phone'];

                        final lat = outlet['partner_latitude'] != null
                            ? asDouble(outlet['partner_latitude'])
                            : (outlet['latitude'] != null ? asDouble(outlet['latitude']) : null);
                        final lng = outlet['partner_longitude'] != null
                            ? asDouble(outlet['partner_longitude'])
                            : (outlet['longitude'] != null ? asDouble(outlet['longitude']) : null);

                        final distanceMeters = ProximityHelper.calculateDistance(
                          userLat: _currentPosition?.latitude,
                          userLng: _currentPosition?.longitude,
                          outletLat: lat,
                          outletLng: lng,
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primarySoft,
                              child: Icon(
                                Icons.storefront,
                                color: AppColors.primaryStrong,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    outlet['name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (distanceMeters != null)
                                  _buildDistanceBadge(
                                    distanceMeters,
                                    lat: lat,
                                    lng: lng,
                                    outletName: outlet['name']?.toString(),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (code != null && code.toString().trim().isNotEmpty) ...[
                                  Text(
                                    'SS Code: ${code.toString().trim()}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (owner != null && owner.toString().trim().isNotEmpty) ...[
                                  Text(
                                    'Owner: ${owner.toString().trim()}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (phone != null && phone.toString().trim().isNotEmpty) ...[
                                  Text(
                                    'Phone: ${phone.toString().trim()}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                Text(
                                  outlet['street'] ?? 'No address',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.more_vert),
                            onTap: () => _showActionDialog(outlet),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
