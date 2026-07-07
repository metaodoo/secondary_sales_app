import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/my_team/my_team_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class SubordinateCheckpointsScreen extends StatefulWidget {
  const SubordinateCheckpointsScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.initialDateStr,
  });

  final int employeeId;
  final String employeeName;
  final String initialDateStr;

  @override
  State<SubordinateCheckpointsScreen> createState() =>
      _SubordinateCheckpointsScreenState();
}

class _SubordinateCheckpointsScreenState
    extends State<SubordinateCheckpointsScreen> {
  late DateTime _selectedDate;
  final MapController _mapController = MapController();
  Checkpoint? _selectedCheckpoint;
  String? _resolvedAddress;
  int? _resolvingCheckpointId;

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
        );
    setState(() {
      _selectedCheckpoint = null;
      _resolvedAddress = null;
      _resolvingCheckpointId = null;
    });
  }

  Future<void> _fetchAddressForCheckpoint(Checkpoint pt) async {
    if (_resolvingCheckpointId == pt.id) return;
    setState(() {
      _resolvedAddress = 'Fetching address...';
      _resolvingCheckpointId = pt.id;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pt.latitude}&lon=${pt.longitude}&zoom=18',
        ),
        headers: {
          'User-Agent': 'Secondary-Sales-Mobile-App/1.0 (info@metamorphosis.com.bd)',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] as String?;
        if (mounted && _resolvingCheckpointId == pt.id) {
          setState(() {
            _resolvedAddress = displayName ?? 'Address not found';
          });
        }
      } else {
        if (mounted && _resolvingCheckpointId == pt.id) {
          setState(() {
            _resolvedAddress = 'Failed to fetch address';
          });
        }
      }
    } catch (e) {
      if (mounted && _resolvingCheckpointId == pt.id) {
        setState(() {
          _resolvedAddress = 'Address unavailable';
        });
      }
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

  void _centerMapOnPoint(Checkpoint point) {
    setState(() {
      _selectedCheckpoint = point;
    });
    _mapController.move(LatLng(point.latitude, point.longitude), 16.0);
    _fetchAddressForCheckpoint(point);
  }

  @override
  Widget build(BuildContext context) {
    final myTeamProvider = context.watch<MyTeamProvider>();
    final shifts = myTeamProvider.checkpointsShifts;

    // Collect all checkpoints across all shifts
    final allCheckpoints = <Checkpoint>[];
    for (final shift in shifts) {
      allCheckpoints.addAll(shift.checkpoints);
    }

    // Determine initial center
    LatLng initialCenter = const LatLng(23.8103, 90.4125); // Default Dhaka coordinates
    if (allCheckpoints.isNotEmpty) {
      initialCenter = LatLng(
        allCheckpoints.first.latitude,
        allCheckpoints.first.longitude,
      );
    }

    // Generate markers
    final markers = <Marker>[];
    for (int i = 0; i < allCheckpoints.length; i++) {
      final pt = allCheckpoints[i];
      final isStart = i == 0;
      final isEnd = i == allCheckpoints.length - 1;

      Color markerColor = AppColors.primary;
      IconData markerIcon = Icons.location_on;
      double size = 30.0;

      if (pt.isMock) {
        markerColor = const Color(0xFFEF4444); // Red warning for mock GPS
        markerIcon = Icons.warning_amber_rounded;
        size = 36.0;
      } else if (isStart) {
        markerColor = const Color(0xFF16A34A); // Green start
        markerIcon = Icons.play_arrow_rounded;
      } else if (isEnd) {
        markerColor = const Color(0xFFDC2626); // Red end
        markerIcon = Icons.stop_rounded;
      }

      markers.add(
        Marker(
          point: LatLng(pt.latitude, pt.longitude),
          width: size,
          height: size,
          child: GestureDetector(
            onTap: () => _centerMapOnPoint(pt),
            child: Container(
              decoration: BoxDecoration(
                color: _selectedCheckpoint?.id == pt.id
                    ? Colors.yellow.shade100
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                markerIcon,
                color: markerColor,
                size: size,
              ),
            ),
          ),
        ),
      );
    }

    // Build polyline points
    final polylinePoints = allCheckpoints
        .map((pt) => LatLng(pt.latitude, pt.longitude))
        .toList();

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
                  'Checkpoints: ${allCheckpoints.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Map tracer panel
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.abrar.secondary_sales',
                    ),
                    if (polylinePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: polylinePoints,
                            color: AppColors.primary.withValues(alpha: 0.7),
                            strokeWidth: 4.5,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: markers),
                    const SimpleAttributionWidget(
                      source: Text('© OpenStreetMap contributors'),
                    ),
                  ],
                ),
                // Floating active point inspector tooltip
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
                          color: _selectedCheckpoint!.isMock
                              ? const Color(0xFFEF4444)
                              : AppColors.borderSoft,
                          width: _selectedCheckpoint!.isMock ? 2 : 1,
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
                                      _selectedCheckpoint!.isMock
                                          ? Icons.warning_amber_rounded
                                          : Icons.info_outline,
                                      color: _selectedCheckpoint!.isMock
                                          ? const Color(0xFFEF4444)
                                          : AppColors.primaryStrong,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedCheckpoint!.isMock
                                          ? 'SPOOF DETECTED'
                                          : 'Checkpoint Info',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _selectedCheckpoint!.isMock
                                            ? const Color(0xFFEF4444)
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
                                Text('Time: ${_selectedCheckpoint!.recordedAt ?? "N/A"}'),
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
                            if (_selectedCheckpoint!.isMock) ...[
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
              final isSelected = _selectedCheckpoint?.id == pt.id;

              return InkWell(
                onTap: () => _centerMapOnPoint(pt),
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
                              color: pt.isMock
                                  ? const Color(0xFFEF4444)
                                  : isSelected
                                      ? AppColors.primaryStrong
                                      : AppColors.primaryTint,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: pt.isMock
                                    ? const Color(0xFFFCA5A5)
                                    : AppColors.primary,
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
