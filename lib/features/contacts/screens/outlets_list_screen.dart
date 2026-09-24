import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/services/location_service.dart';
import 'package:secondary_sales/core/util/proximity_helper.dart';
import 'package:secondary_sales/core/util/parse.dart';
import 'package:secondary_sales/data/models/sales/order_line_entry.dart';
import 'package:secondary_sales/features/contacts/screens/edit_outlet_screen.dart';
import 'package:secondary_sales/features/sales/screens/order_creation_screen.dart';
import 'package:secondary_sales/features/sales/screens/product_selection_screen.dart';

class OutletsListScreen extends StatefulWidget {
  const OutletsListScreen({super.key, this.startSecondarySale = false});

  final bool startSecondarySale;

  @override
  State<OutletsListScreen> createState() => _OutletsListScreenState();
}

class _OutletsListScreenState extends State<OutletsListScreen> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _outlets = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  StreamSubscription<Position>? _positionStreamSub;
  Position? _currentPosition;
  bool _sortByNearest = false;
  bool _isGpsRefreshing = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchOutlets(reset: true);
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
          debugPrint('Location stream error in OutletsListScreen: $e');
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
      debugPrint('Error getting GPS in OutletsListScreen: $e');
    } finally {
      if (mounted) {
        setState(() => _isGpsRefreshing = false);
      }
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchOutlets();
    }
  }

  Future<void> _fetchOutlets({bool reset = false, String? search}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _isLoadingMore = false;
    }
    if (!reset && (!_hasMore || _isLoadingMore)) {
      return;
    }

    if (!mounted) return;
    setState(() {
      if (reset) {
        _isLoading = true;
        _error = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final provider = Provider.of<RouteProvider>(context, listen: false);
      final query = search ?? _searchController.text;
      // Fetch ALL outlets by passing assigned: null
      final outlets = await provider.fetchAllOutlets(
        search: query,
        assigned: null,
        page: _page,
        pageSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          if (reset) {
            _outlets = outlets;
          } else {
            _outlets.addAll(outlets);
          }
          _hasMore = outlets.length == _pageSize;
          if (_hasMore) {
            _page += 1;
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchOutlets(reset: true, search: value);
    });
  }

  void _openOutlet(Map<String, dynamic> outlet) {
    if (widget.startSecondarySale) {
      final outletId = outlet['id'];
      if (outletId is! int) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This outlet cannot be selected.')),
        );
        return;
      }

      final name = outlet['name'] as String? ?? 'Unnamed Outlet';
      final code = outlet['ss_code'] ?? outlet['code'];
      final rawCode = (code != null && code.toString().trim().isNotEmpty)
          ? code.toString().trim()
          : null;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductSelectionScreen(
            saleType: 'secondary',
            partnerId: outletId,
            customerName: name,
            customerCode: rawCode,
          ),
        ),
      );
      return;
    }

    _editOutlet(outlet);
  }

  Future<void> _editOutlet(Map<String, dynamic> outlet) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditOutletScreen(outlet: outlet)),
    );
    if (updated == true) {
      _fetchOutlets(reset: true);
    }
  }

  Widget _buildDistanceBadge(
    double distanceMeters, {
    required Map<String, dynamic> outlet,
  }) {
    final formatted = ProximityHelper.formatDistance(distanceMeters);
    final lat = outlet['partner_latitude'] is num
        ? (outlet['partner_latitude'] as num).toDouble()
        : (outlet['latitude'] is num ? (outlet['latitude'] as num).toDouble() : null);
    final lng = outlet['partner_longitude'] is num
        ? (outlet['partner_longitude'] as num).toDouble()
        : (outlet['longitude'] is num ? (outlet['longitude'] as num).toDouble() : null);
    final name = outlet['name'] as String? ?? 'Outlet';

    return InkWell(
      onTap: () {
        ProximityHelper.openGoogleMapsDirections(
          context: context,
          destinationLat: lat,
          destinationLng: lng,
          originLat: _currentPosition?.latitude,
          originLng: _currentPosition?.longitude,
          destinationTitle: name,
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
    List<Map<String, dynamic>> displayedOutlets = List.from(_outlets);

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
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.startSecondarySale ? 'Select Outlet' : 'Outlets',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ProfileAvatar(currentDestinationLabel: 'Outlets'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchOutlets(reset: true),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screen,
              vertical: AppSpacing.screen,
            ),
            children: [
              TextField(
                controller: _searchController,
                decoration: ssInputDecoration(
                  'Search outlets...',
                  Icons.search,
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 8),
              // Proximity & GPS Toolbar
              Row(
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
              const SizedBox(height: 12),
              if (_error != null) ErrorPanel(_error!),
              if (_isLoading && displayedOutlets.isNotEmpty) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              if (_isLoading && displayedOutlets.isEmpty)
                const LoadingState()
              else if (displayedOutlets.isEmpty)
                const EmptyPanel(message: 'No outlets found')
              else
                ...displayedOutlets.map((outlet) {
                  final name = outlet['name'] as String? ?? 'Unnamed Outlet';
                  final rawCode = outlet['ss_code'] ?? outlet['code'];
                  final codeStr = (rawCode != null && rawCode.toString().trim().isNotEmpty)
                      ? rawCode.toString().trim()
                      : null;
                  final street =
                      outlet['street'] as String? ?? 'No address provided';

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

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openOutlet(outlet),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: AppColors.borderMuted,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (distanceMeters != null)
                                        _buildDistanceBadge(
                                          distanceMeters,
                                          outlet: outlet,
                                        ),
                                    ],
                                  ),
                                  if (codeStr != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Code: $codeStr',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    street,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                widget.startSecondarySale
                                    ? Icons.shopping_cart_checkout
                                    : Icons.edit_outlined,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => _openOutlet(outlet),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
