import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/core/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
import 'package:secondary_sales/features/my_team/my_team_provider.dart';
import 'package:secondary_sales/core/util/dialog_helper.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class CreateOutletScreen extends StatefulWidget {
  final int routeId;
  final String routeName;
  final String distributorName;

  const CreateOutletScreen({
    super.key,
    required this.routeId,
    required this.routeName,
    required this.distributorName,
  });

  @override
  State<CreateOutletScreen> createState() => _CreateOutletScreenState();
}

class _CreateOutletScreenState extends State<CreateOutletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _ownerNameController = TextEditingController();

  File? _capturedPhoto;
  String? _locationError;
  double? _capturedLatitude;
  double? _capturedLongitude;
  double? _capturedAccuracy;
  bool _isResolvingAddress = false;
  bool _isSaving = false;

  StreamSubscription<Position>? _warmupSubscription;
  Position? _warmedPosition;

  int? _selectedOutletTypeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RouteProvider>(context, listen: false);
      provider.fetchOutletTypes();
      _startGpsWarmup();
    });
  }

  /// Silently wakes up the GPS satellite receiver in the background so that
  /// satellite lock is established by the time the rep snaps the outlet photo.
  void _startGpsWarmup() {
    try {
      _warmupSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen(
        (pos) {
          if (_warmedPosition == null || pos.accuracy < _warmedPosition!.accuracy) {
            _warmedPosition = pos;
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _warmupSubscription?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _ownerNameController.dispose();
    super.dispose();
  }

  Future<void> _captureOutletPhoto() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (photo == null) return;

      final persistentFile = await MediaStorageService.persistPickedFile(
        photo,
        category: MediaCategory.outlets,
        customPrefix: 'outlet_registration',
      );

      setState(() => _capturedPhoto = persistentFile ?? File(photo.path));

      // Always capture GPS location freshly at the moment the photo is taken
      await _captureLocation();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResolvingAddress = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  /// Fixes the outlet's position using high-precision satellite sampling.
  /// Filters out coarse cell-tower / Wi-Fi triangulation to ensure accurate geofencing.
  Future<void> _captureLocation() async {
    if (_isResolvingAddress) return;
    setState(() {
      _isResolvingAddress = true;
      _locationError = null;
    });

    try {
      Position position;
      // If the background warmup already has a sharp satellite fix (<= 25m), use it
      if (_warmedPosition != null && _warmedPosition!.accuracy <= 25.0) {
        position = _warmedPosition!;
      } else {
        position = await LocationService.getAccuratePosition(
          desiredAccuracyInMeters: 30.0,
          timeLimit: const Duration(seconds: 12),
        );
      }

      if (!mounted) return;
      setState(() {
        _capturedLatitude = position.latitude;
        _capturedLongitude = position.longitude;
        _capturedAccuracy = position.accuracy;
        _isResolvingAddress = true;
      });

      await _resolveAddress(position.latitude, position.longitude);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResolvingAddress = false;
        _capturedLatitude = null;
        _capturedLongitude = null;
        _capturedAccuracy = null;
        _locationError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _resolveAddress(double latitude, double longitude) async {
    try {
      final resolved = await Provider.of<MyTeamProvider>(
        context,
        listen: false,
      ).reverseGeocode(latitude: latitude, longitude: longitude);
      if (!mounted) return;
      if (resolved != null && resolved.trim().isNotEmpty) {
        // Never overwrite something the rep has typed themselves.
        if (_addressController.text.trim().isEmpty) {
          setState(() {
            _addressController.text = resolved.trim();
          });
        }
      }
    } catch (e) {
      debugPrint('[CreateOutletScreen] Reverse geocode error: $e');
    } finally {
      if (mounted) {
        setState(() => _isResolvingAddress = false);
      }
    }
  }

  Future<void> _saveOutlet() async {
    if (!_formKey.currentState!.validate()) return;

    if (_capturedPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must capture a live photo of the outlet using the camera.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Without a fix there is no geofence centre, so every future check-in at
    // this outlet would fail. Saving nulls silently is what let that happen.
    if (_capturedLatitude == null || _capturedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _locationError == null
                ? 'Waiting for the outlet location. Try again in a moment.'
                : 'Outlet location not captured: $_locationError',
          ),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: _captureLocation,
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = Provider.of<RouteProvider>(context, listen: false);

    try {
      final bytes = await _capturedPhoto!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final newOutlet = await provider.addOutletToRoute(
        widget.routeId,
        name: _nameController.text.trim(),
        mobile: _phoneController.text.trim(),
        phone: _phoneController.text.trim(),
        street: _addressController.text.trim(),
        outletOwnerName: _ownerNameController.text.trim(),
        partnerLatitude: _capturedLatitude,
        partnerLongitude: _capturedLongitude,
        image1920: base64Image,
        outletTypeId: _selectedOutletTypeId,
      );

      setState(() => _isSaving = false);

      if (!mounted) return;

      if (newOutlet != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Outlet created successfully')),
        );
        Navigator.pop(context, true);
      } else {
        await showValidationErrorDialog(
          context,
          provider.error ?? 'Failed to create outlet',
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        await showValidationErrorDialog(context, e.toString());
      }
    }
  }

  /// Standalone location capture: status, reason, and an action that matches
  /// the reason. A permission problem needs Settings, not another retry.
  Widget _buildLocationRow() {
    final bool hasFix = _capturedLatitude != null && _capturedLongitude != null;
    final String reason = _locationError ?? '';
    final bool needsSettings =
        reason.toLowerCase().contains('denied') ||
        reason.toLowerCase().contains('disabled');

    final double? acc = _capturedAccuracy;
    final bool isHighAcc = acc != null && acc <= 35.0;
    final bool isLowAcc = acc != null && acc > 100.0;

    final Color accent = hasFix
        ? (isLowAcc ? Colors.amber.shade800 : AppColors.primary)
        : (_isResolvingAddress ? AppColors.textSecondary : Colors.red.shade700);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFix
              ? (isLowAcc ? Colors.amber.shade400 : AppColors.borderSoft)
              : accent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasFix
                ? (isLowAcc ? Icons.gps_not_fixed : Icons.my_location)
                : Icons.location_disabled,
            size: 20,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hasFix ? 'Outlet Location Captured' : 'Outlet Location *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hasFix ? AppColors.textPrimary : accent,
                      ),
                    ),
                    if (hasFix && acc != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isLowAcc
                              ? Colors.amber.shade50
                              : (isHighAcc
                                  ? Colors.green.shade50
                                  : Colors.blue.shade50),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isLowAcc
                                ? Colors.amber.shade400
                                : (isHighAcc
                                    ? Colors.green.shade400
                                    : Colors.blue.shade400),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          isLowAcc
                              ? '±${acc.toStringAsFixed(0)}m (Low)'
                              : '±${acc.toStringAsFixed(0)}m (Accurate)',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isLowAcc
                                ? Colors.amber.shade900
                                : (isHighAcc
                                    ? Colors.green.shade800
                                    : Colors.blue.shade800),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasFix
                      ? 'Lat: ${_capturedLatitude!.toStringAsFixed(6)}, Lon: ${_capturedLongitude!.toStringAsFixed(6)}'
                      : _isResolvingAddress
                      ? 'Acquiring high-accuracy GPS…'
                      : (reason.isEmpty ? 'Will be captured when photo is taken' : reason),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_isResolvingAddress)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: needsSettings
                  ? () => Geolocator.openAppSettings()
                  : _captureLocation,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryStrong,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                needsSettings
                    ? 'SETTINGS'
                    : (hasFix ? 'RECAPTURE' : 'CAPTURE'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
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
        title: const Text(
          'Create Outlet',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ProfileAvatar(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Outlet Entry',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fill in the missing details to register this location under the selected distributor.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OUTLET IMAGE & LOCATION',
                      style: TextStyle(
                        color: AppColors.primaryStrong,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _captureOutletPhoto,
                      child: Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.borderMuted.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _capturedPhoto == null
                                ? AppColors.borderSoft
                                : AppColors.primaryStrong.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: _capturedPhoto == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Capture Live Outlet Photo *',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Restricted to direct device camera',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  children: [
                                    Image.file(
                                      _capturedPhoto!,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                    Container(
                                      color: Colors.black.withOpacity(0.4),
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      right: 12,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on,
                                                color: Colors.redAccent,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _capturedLatitude != null &&
                                                        _capturedLongitude !=
                                                            null
                                                    ? 'Lat: ${_capturedLatitude!.toStringAsFixed(6)}, Lon: ${_capturedLongitude!.toStringAsFixed(6)}'
                                                    : _isResolvingAddress
                                                    ? 'Getting location…'
                                                    : (_locationError ??
                                                          'Location not captured'),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_isResolvingAddress)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                top: 4.0,
                                              ),
                                              child: Text(
                                                'Resolving address details...',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.replay_outlined,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Retake',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    // A location fix independent of the photo. The two were welded together,
                    // so a failed fix could only be retried by retaking the picture -- and on
                    // a phone where permission is permanently denied, retaking never helps.
                    _buildLocationRow(),

                    const SizedBox(height: 24),
                    const Text(
                      'OUTLET DETAILS',
                      style: TextStyle(
                        color: AppColors.primaryStrong,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Customer Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter customer name'
                          : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.borderMuted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Outlet Owner Name *',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ownerNameController,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter owner name'
                          : null,
                      decoration: InputDecoration(
                        hintText: 'Enter owner name',
                        filled: true,
                        fillColor: AppColors.borderMuted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer<RouteProvider>(
                      builder: (context, provider, _) {
                        final types = provider.outletTypes;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Outlet Type *',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: _selectedOutletTypeId,
                              validator: (val) => val == null
                                  ? 'Outlet Type is required'
                                  : null,
                              decoration: InputDecoration(
                                hintText: types.isEmpty
                                    ? 'No types found'
                                    : 'Select Type',
                                filled: true,
                                fillColor: AppColors.borderMuted,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: types.map((t) {
                                return DropdownMenuItem<int>(
                                  value: t.id,
                                  child: Text(t.name),
                                );
                              }).toList(),
                              onChanged: types.isEmpty
                                  ? null
                                  : (val) {
                                      setState(() => _selectedOutletTypeId = val);
                                    },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Card style for Route & Distributor (DB) assignment
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.alt_route_rounded,
                                  size: 16,
                                  color: AppColors.primaryStrong,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ASSIGNED ROUTE & DISTRIBUTOR',
                                style: TextStyle(
                                  color: AppColors.primaryStrong,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFA7F3D0),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 11,
                                      color: Color(0xFF059669),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Auto-Assigned',
                                      style: TextStyle(
                                        color: Color(0xFF059669),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 12),
                          // Route Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 95,
                                child: Text(
                                  'Route Name',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.routeName.isNotEmpty
                                      ? widget.routeName
                                      : 'Unassigned Route',
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // DB / Distributor Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 95,
                                child: Text(
                                  'Distributor (DB)',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.distributorName.isNotEmpty
                                      ? widget.distributorName
                                      : 'Unassigned Distributor',
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: AppColors.borderSoft),
                    const SizedBox(height: 24),
                    const Text(
                      'CONTACT INFORMATION',
                      style: TextStyle(
                        color: AppColors.primaryStrong,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Phone number is required'
                          : null,
                      decoration: InputDecoration(
                        hintText: 'Enter mobile number',
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Address',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Street name, building, floor...',
                        helperText: _isResolvingAddress
                            ? 'Resolving address via Barikoi...'
                            : null,
                        helperStyle: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                        suffixIcon: _isResolvingAddress
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AppColors.borderSoft,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveOutlet,
        backgroundColor: AppColors.primaryStrong,
        elevation: 4,
        icon: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check, color: Colors.white),
        label: const Text(
          'Create Outlet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
