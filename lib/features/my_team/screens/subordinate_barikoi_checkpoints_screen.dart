import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/my_team/my_team_provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:intl/intl.dart';

class ProcessedCheckpoint {
  final Checkpoint original;
  final bool isStop;
  final int duration;

  ProcessedCheckpoint({
    required this.original,
    this.isStop = false,
    this.duration = 0,
  });
}

class SubordinateBarikoiCheckpointsScreen extends StatefulWidget {
  const SubordinateBarikoiCheckpointsScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.initialDateStr,
  });

  final int employeeId;
  final String employeeName;
  final String initialDateStr;

  @override
  State<SubordinateBarikoiCheckpointsScreen> createState() =>
      _SubordinateBarikoiCheckpointsScreenState();
}

class _SubordinateBarikoiCheckpointsScreenState
    extends State<SubordinateBarikoiCheckpointsScreen> {
  late DateTime _selectedDate;
  MapLibreMapController? _mapController;
  ProcessedCheckpoint? _selectedCheckpoint;
  String? _resolvedAddress;
  int? _resolvingCheckpointId;
  List<ProcessedCheckpoint> _processedCheckpoints = [];
  bool _styleLoaded = false;
  int? _selectedShiftIndex;
  String _drawStatus = 'draw not called yet';

  static const String _lineSourceId = 'route-line-src';
  static const String _lineLayerId = 'route-line-layer';
  static const String _pointSourceId = 'route-points-src';
  static const String _pointLayerId = 'route-points-layer';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.tryParse(widget.initialDateStr) ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCheckpoints();
    });
  }

  void _fetchCheckpoints() {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    context.read<MyTeamProvider>().fetchEmployeeCheckpoints(
          employeeId: widget.employeeId,
          date: formattedDate,
        ).then((_) {
          if (mounted) {
            _processLocationPoints();
            // Always redraw — _drawRoute() self-guards on _styleLoaded, and it
            // is what clears the previous date's layers. Gating the call here
            // would leave a stale route on screen for dates with no data.
            _drawRoute();
          }
        });
    setState(() {
      _selectedCheckpoint = null;
      _resolvedAddress = null;
      _resolvingCheckpointId = null;
      _selectedShiftIndex = null;
    });
  }

  // Calculate distance in meters using Haversine formula
  double _getDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final phi1 = lat1 * pi / 180.0;
    final phi2 = lat2 * pi / 180.0;
    final deltaPhi = (lat2 - lat1) * pi / 180.0;
    final deltaLambda = (lon2 - lon1) * pi / 180.0;
    final a = sin(deltaPhi / 2.0) * sin(deltaPhi / 2.0) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2.0) * sin(deltaLambda / 2.0);
    final c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
    return r * c;
  }

  // Calculate duration in minutes between two timestamps
  int _getDuration(String? t1Str, String? t2Str) {
    if (t1Str == null || t2Str == null) return 0;
    final t1 = DateTime.tryParse(t1Str);
    final t2 = DateTime.tryParse(t2Str);
    if (t1 == null || t2 == null) return 0;
    return t2.difference(t1).inMinutes;
  }

  // Process data-driven states of location coordinates
  void _processLocationPoints() {
    final shifts = context.read<MyTeamProvider>().checkpointsShifts;
    final List<ProcessedCheckpoint> processed = [];

    for (int sIdx = 0; sIdx < shifts.length; sIdx++) {
      if (_selectedShiftIndex != null && _selectedShiftIndex != sIdx) {
        continue;
      }
      final shift = shifts[sIdx];
      final shiftPts = shift.checkpoints;
      for (int i = 0; i < shiftPts.length; i++) {
        final pt = shiftPts[i];
        bool isStop = false;
        int duration = 0;

        if (i < shiftPts.length - 1) {
          final nextPt = shiftPts[i + 1];
          final dist = _getDistance(pt.latitude, pt.longitude, nextPt.latitude, nextPt.longitude);
          final dur = _getDuration(pt.recordedAt, nextPt.recordedAt);

          // Stationary for >= 5 minutes within 50 meters
          if (dist < 50 && dur >= 5) {
            isStop = true;
            duration = dur;
          }
        }

        processed.add(ProcessedCheckpoint(
          original: pt,
          isStop: isStop,
          duration: duration,
        ));
      }
    }

    setState(() {
      _processedCheckpoints = processed;
    });
  }

  void _setStatus(String s) {
    if (!mounted) {
      _drawStatus = s;
      return;
    }
    setState(() => _drawStatus = s);
  }

  /// Serializes route draws. Concurrent calls (the style-loaded callback racing
  /// the 2s creation fallback, or a shift tap landing while a fetch resolves)
  /// interleave their awaits: one removes the sources the other just added, and
  /// the add then fails with "source already exists" — leaving the map blank.
  Future<void> _drawInFlight = Future<void>.value();

  Future<void> _drawRoute() {
    _drawInFlight =
        _drawInFlight.then((_) => _drawRouteImpl()).catchError((_) {});
    return _drawInFlight;
  }

  Future<void> _drawRouteImpl() async {
    // Queued draws can run after the screen is gone; context is unusable then.
    if (!mounted) return;
    final controller = _mapController;
    if (controller == null) {
      _setStatus('no map controller');
      return;
    }
    if (!_styleLoaded) {
      _setStatus('style not loaded yet');
      return;
    }

    // Read shift data synchronously, before any await, so BuildContext is not
    // used across an async gap.
    final shifts = context.read<MyTeamProvider>().checkpointsShifts;

    // Remove any previously drawn route layers/sources. Wrapped because the ids
    // may not exist yet (first draw) or after a style reload.
    for (final id in const [_pointLayerId, _lineLayerId]) {
      try {
        await controller.removeLayer(id);
      } catch (_) {}
    }
    for (final id in const [_pointSourceId, _lineSourceId]) {
      try {
        await controller.removeSource(id);
      } catch (_) {}
    }

    if (_processedCheckpoints.isEmpty) {
      _setStatus('0 processed checkpoints');
      return;
    }

    // Render the whole route as two GeoJSON layers (one line, one circle)
    // instead of thousands of per-point annotations. A single source + a
    // data-driven layer is what MapLibre is built for and renders reliably at
    // these counts (~2900 points), where per-annotation calls did not show up.
    final lineFeatures = <Map<String, dynamic>>[];
    final pointFeatures = <Map<String, dynamic>>[];

    for (int sIdx = 0; sIdx < shifts.length; sIdx++) {
      if (_selectedShiftIndex != null && _selectedShiftIndex != sIdx) {
        continue;
      }
      final shiftPts = shifts[sIdx].checkpoints;

      for (int i = 0; i < shiftPts.length; i++) {
        final ptOriginal = shiftPts[i];
        final isStart = i == 0;
        final isEnd = i == shiftPts.length - 1;

        final pt = _processedCheckpoints.firstWhere(
          (element) => element.original.id == ptOriginal.id,
          orElse: () => ProcessedCheckpoint(original: ptOriginal),
        );

        // Point styling
        String circleColor = "#3b82f6"; // Default Blue
        double radius = 6.0;
        double strokeWidth = 1.5;
        if (pt.original.isMock) {
          circleColor = "#ef4444";
          radius = 8.0;
          strokeWidth = 2.0;
        } else if (isStart) {
          circleColor = "#16a34a";
          radius = 10.0;
          strokeWidth = 2.5;
        } else if (isEnd) {
          circleColor = "#1f2937";
          radius = 10.0;
          strokeWidth = 2.5;
        } else if (pt.isStop) {
          if (pt.duration >= 15) {
            circleColor = "#d97706";
            radius = 10.0;
            strokeWidth = 2.0;
          } else {
            circleColor = "#f59e0b";
            radius = 8.0;
            strokeWidth = 1.5;
          }
        }

        pointFeatures.add({
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [ptOriginal.longitude, ptOriginal.latitude],
          },
          "properties": {
            "color": circleColor,
            "radius": radius,
            "stroke": strokeWidth,
            "cid": ptOriginal.id,
          },
        });

        // Line segment to the next point
        if (i < shiftPts.length - 1) {
          final nextPtOriginal = shiftPts[i + 1];
          String lineColor = "#3b82f6";
          double lineWidth = 4.5;
          if (pt.original.isMock) {
            lineColor = "#ef4444";
            lineWidth = 5.0;
          } else if (pt.isStop) {
            if (pt.duration >= 15) {
              lineColor = "#d97706";
              lineWidth = 6.0;
            } else {
              lineColor = "#f59e0b";
              lineWidth = 5.0;
            }
          }
          lineFeatures.add({
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [ptOriginal.longitude, ptOriginal.latitude],
                [nextPtOriginal.longitude, nextPtOriginal.latitude],
              ],
            },
            "properties": {"color": lineColor, "width": lineWidth},
          });
        }
      }
    }

    _setStatus('built L=${lineFeatures.length} P=${pointFeatures.length}, adding…');
    try {
      await controller.addGeoJsonSource(_lineSourceId, {
        "type": "FeatureCollection",
        "features": lineFeatures,
      });
      await controller.addLineLayer(
        _lineSourceId,
        _lineLayerId,
        LineLayerProperties(
          lineColor: ["get", "color"],
          lineWidth: ["get", "width"],
          lineOpacity: 0.85,
          lineJoin: "round",
          lineCap: "round",
        ),
      );
      await controller.addGeoJsonSource(
        _pointSourceId,
        {"type": "FeatureCollection", "features": pointFeatures},
        promoteId: "cid",
      );
      await controller.addCircleLayer(
        _pointSourceId,
        _pointLayerId,
        CircleLayerProperties(
          circleColor: ["get", "color"],
          circleRadius: ["get", "radius"],
          circleStrokeColor: "#ffffff",
          circleStrokeWidth: ["get", "stroke"],
        ),
      );
      _setStatus('added OK · L=${lineFeatures.length} '
          'P=${pointFeatures.length} shifts=${shifts.length}');
    } catch (e) {
      _setStatus('ADD ERROR: $e');
    }

    // 3. Auto-fit camera boundaries
    double? minLat, maxLat, minLng, maxLng;
    for (final pt in _processedCheckpoints) {
      final lat = pt.original.latitude;
      final lng = pt.original.longitude;
      if (minLat == null || lat < minLat) minLat = lat;
      if (maxLat == null || lat > maxLat) maxLat = lat;
      if (minLng == null || lng < minLng) minLng = lng;
      if (maxLng == null || lng > maxLng) maxLng = lng;
    }

    if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
      if (_processedCheckpoints.length == 1) {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 16.0),
        );
      } else {
        controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            left: 50,
            top: 150, // Added padding to clear floating widgets
            right: 50,
            bottom: 50,
          ),
        );
      }
    }
  }

  Future<void> _fetchAddressForCheckpoint(Checkpoint pt) async {
    if (_resolvingCheckpointId == pt.id) return;
    setState(() {
      _resolvedAddress = 'Fetching address...';
      _resolvingCheckpointId = pt.id;
    });

    final address = await context.read<MyTeamProvider>().reverseGeocode(
          latitude: pt.latitude,
          longitude: pt.longitude,
        );

    // Ignore a response for a checkpoint the user has already tapped away from.
    if (mounted && _resolvingCheckpointId == pt.id) {
      setState(() {
        _resolvedAddress = address ?? 'Address unavailable';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryStrong,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchCheckpoints();
    }
  }

  void _centerMapOnPoint(ProcessedCheckpoint point) {
    setState(() {
      _selectedCheckpoint = point;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(point.original.latitude, point.original.longitude),
        16.5,
      ),
    );
    _fetchAddressForCheckpoint(point.original);
  }

  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != _pointLayerId || _processedCheckpoints.isEmpty) return;

    final cid = int.tryParse(id);
    final match = _processedCheckpoints.firstWhere(
      (pt) => pt.original.id == cid,
      orElse: () => _processedCheckpoints.first,
    );

    _centerMapOnPoint(match);
  }

  @override
  Widget build(BuildContext context) {
    final myTeamProvider = context.watch<MyTeamProvider>();
    final shifts = myTeamProvider.checkpointsShifts;
    final barikoiKey = myTeamProvider.barikoiApiKey ?? '';

    // Style URL with the API key retrieved dynamically from Odoo backend
    final mapUrl = 'https://map.barikoi.com/styles/osm-liberty/style.json?key=$barikoiKey';

    LatLng initialCenter = const LatLng(23.8103, 90.4125); // Default Dhaka center
    if (_processedCheckpoints.isNotEmpty) {
      initialCenter = LatLng(
        _processedCheckpoints.first.original.latitude,
        _processedCheckpoints.first.original.longitude,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.employeeName,
          style: const TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryStrong),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: AppColors.primaryStrong),
            onPressed: () => _selectDate(context),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: ProfileAvatar(),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Subheader info panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Checkpoints: ${_processedCheckpoints.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Shift Selector Tabs
          if (shifts.length > 1)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.borderSoft)),
              ),
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: shifts.length + 1,
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final isSelected = isAll 
                      ? _selectedShiftIndex == null 
                      : _selectedShiftIndex == index - 1;
                  
                  final label = isAll 
                      ? 'All Shifts' 
                      : 'Shift $index';

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedShiftIndex = isAll ? null : index - 1;
                      });
                      _processLocationPoints();
                      _drawRoute();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8.0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Map tracer panel
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                if (barikoiKey.isEmpty && myTeamProvider.isLoading)
                  const Center(
                    child: LoadingState(message: 'Initializing map parameters...'),
                  )
                else if (barikoiKey.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Barikoi API Key missing or map not configured.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else
                MapLibreMap(
                    initialCameraPosition: CameraPosition(
                      target: initialCenter,
                      zoom: 15.0,
                    ),
                    styleString: mapUrl,
                    onMapCreated: (MapLibreMapController mapController) {
                      _mapController = mapController;
                      _mapController?.onFeatureTapped.add(_onFeatureTapped);
                      // Fallback: on some devices/styles onStyleLoadedCallback
                      // does not fire, leaving _styleLoaded false and the route
                      // undrawn. Force a draw shortly after creation.
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted && !_styleLoaded) {
                          _styleLoaded = true;
                          _drawRoute();
                        }
                      });
                    },
                    onStyleLoadedCallback: () {
                      _styleLoaded = true;
                      _drawRoute();
                    },
                  ),

                // Diagnostic overlay — shows the map-draw state on the device
                // itself (no console needed when side-loading an APK).
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'MAP: $_drawStatus',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Map Legend Overlays
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderSoft),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Route Legend',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: Color(0xFF3B82F6)),
                            SizedBox(width: 6),
                            Text('Active Movement', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: Color(0xFFF59E0B)),
                            SizedBox(width: 6),
                            Text('Short Stop (<15m)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: Color(0xFFD97706)),
                            SizedBox(width: 6),
                            Text('Major Stop (>=15m)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: Color(0xFFEF4444)),
                            SizedBox(width: 6),
                            Text('Mock Location', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating active checkpoint inspector tooltip
                if (_selectedCheckpoint != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Card(
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _selectedCheckpoint!.original.isMock
                              ? const Color(0xFFEF4444)
                              : AppColors.borderSoft,
                          width: _selectedCheckpoint!.original.isMock ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _selectedCheckpoint!.original.isMock
                                          ? Icons.warning_amber_rounded
                                          : _selectedCheckpoint!.isStop
                                              ? Icons.pause_circle_outline
                                              : Icons.info_outline,
                                      color: _selectedCheckpoint!.original.isMock
                                          ? const Color(0xFFEF4444)
                                          : _selectedCheckpoint!.isStop
                                              ? const Color(0xFFD97706)
                                              : AppColors.primaryStrong,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedCheckpoint!.original.isMock
                                          ? 'SPOOF DETECTED'
                                          : _selectedCheckpoint!.isStop
                                              ? 'Stop Duration: ${_selectedCheckpoint!.duration} mins'
                                              : 'Checkpoint Info',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _selectedCheckpoint!.original.isMock
                                            ? const Color(0xFFEF4444)
                                            : _selectedCheckpoint!.isStop
                                                ? const Color(0xFFD97706)
                                                : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _selectedCheckpoint = null;
                                      _resolvedAddress = null;
                                      _resolvingCheckpointId = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Time: ${_selectedCheckpoint!.original.recordedAt ?? "N/A"}'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Address: ${_resolvedAddress ?? "Fetching address..."}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_selectedCheckpoint!.original.isMock) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.security, size: 14, color: Color(0xFFEF4444)),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'WARNING: Location reported via fake mock GPS providers.',
                                        style: TextStyle(
                                          color: Color(0xFFB91C1C),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Subordinate shift details timeline list
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              child: myTeamProvider.isLoading
                  ? const Center(
                      child: LoadingState(message: 'Updating path logs...'),
                    )
                  : shifts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.map_outlined, size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  'No attendance shifts or checkpoints logged on ${DateFormat('MMMM dd, yyyy').format(_selectedDate)}.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: shifts.length,
                          itemBuilder: (context, shiftIndex) {
                            if (_selectedShiftIndex != null && _selectedShiftIndex != shiftIndex) {
                              return const SizedBox.shrink();
                            }
                            final shift = shifts[shiftIndex];
                            return _buildShiftTimeline(context, shift, shiftIndex + 1);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftTimeline(BuildContext context, AttendanceShift shift, int shiftNum) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shift title/header
        Container(
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primaryTint),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Check-In: ${shift.checkIn != null ? shift.checkIn!.split(" ").last : "N/A"}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryStrong,
                ),
              ),
              Text(
                'Check-Out: ${shift.checkOut != null ? shift.checkOut!.split(" ").last : "Active"}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryStrong,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Checkpoints in this shift
        if (shift.checkpoints.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 16.0, top: 4.0),
            child: Text(
              'No GPS locations synchronized for this shift.',
              style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shift.checkpoints.length,
            itemBuilder: (context, ptIndex) {
              final pt = shift.checkpoints[ptIndex];
              // Map back original checkpoint to processed checkpoint to keep UI selection consistent
              final procPtIndex = _processedCheckpoints.indexWhere((element) => element.original.id == pt.id);
              final procPt = procPtIndex != -1 ? _processedCheckpoints[procPtIndex] : ProcessedCheckpoint(original: pt);
              final isSelected = _selectedCheckpoint?.original.id == pt.id;

              Color indicatorColor = AppColors.primaryTint;
              Color borderColor = AppColors.primary;
              if (pt.isMock) {
                indicatorColor = const Color(0xFFEF4444);
                borderColor = const Color(0xFFFCA5A5);
              } else if (procPt.isStop) {
                indicatorColor = procPt.duration >= 15 ? const Color(0xFFD97706) : const Color(0xFFF59E0B);
                borderColor = procPt.duration >= 15 ? const Color(0xFFFBBF24) : const Color(0xFFFDE68A);
              } else if (isSelected) {
                indicatorColor = AppColors.primaryStrong;
              }

              return InkWell(
                onTap: () => _centerMapOnPoint(procPt),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade50.withValues(alpha: 0.5) : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(color: AppColors.borderMuted),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Timeline indicator node
                      Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: indicatorColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: borderColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Time
                      Text(
                        pt.recordedAt?.split(" ").last ?? 'N/A',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: pt.isMock ? const Color(0xFFEF4444) : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Lat/Lng overview
                      Expanded(
                        child: Text(
                          isSelected && _resolvedAddress != null
                              ? _resolvedAddress!
                              : '${pt.latitude.toStringAsFixed(5)}, ${pt.longitude.toStringAsFixed(5)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            fontFamily: isSelected && _resolvedAddress != null ? null : 'monospace',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Stop badge
                      if (procPt.isStop)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: procPt.duration >= 15 ? const Color(0xFFFEF3C7) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: procPt.duration >= 15 ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'STOP ${procPt.duration}m',
                            style: TextStyle(
                              color: procPt.duration >= 15 ? const Color(0xFFB45309) : const Color(0xFFD97706),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      // Spoof / Mock indicator
                      if (pt.isMock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SPOOF',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
