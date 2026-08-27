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
  bool _isResolvingAddress = false;
  bool _isSaving = false;
  DateTime? _locationCapturedAt;

  int? _selectedOutletClassId;
  int? _selectedOutletTypeId;

  /// How long a fix stays usable. The rep is standing at the shop for the whole
  /// form, so a fix taken when the screen opened is the same place as one taken
  /// after the photo -- and reusing it saves the 5-10s the rep would otherwise
  /// spend watching a spinner.
  static const Duration _locationFreshFor = Duration(minutes: 3);

  bool get _hasFreshLocation {
    final at = _locationCapturedAt;
    if (_capturedLatitude == null || _capturedLongitude == null || at == null) {
      return false;
    }
    return DateTime.now().difference(at) < _locationFreshFor;
  }

  @override
  void initState() {
    super.initState();
    // Warm the fix while the rep is still typing the name. The GPS chipset
    // needs seconds to settle; doing it here rather than after the photo means
    // that cost overlaps with form filling instead of being dead wait.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureLocation();
      final provider = Provider.of<RouteProvider>(context, listen: false);
      provider.fetchOutletClasses();
      provider.fetchOutletTypes();
    });
  }

  @override
  void dispose() {
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
        imageQuality: 70,
      );

      if (photo == null) return;

      setState(() => _capturedPhoto = File(photo.path));

      // A fix from the warm-up is the same shop, so don't make the rep wait
      // for a second one. Only fix again if there isn't a usable position.
      if (!_hasFreshLocation) await _captureLocation();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResolvingAddress = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  /// Fixes the outlet's position, separately from the photo so a failed fix can
  /// be retried without making the rep retake the picture.
  ///
  /// A fresh fix is required rather than falling back to the last known one:
  /// this coordinate becomes the outlet's permanent geofence centre, so a stale
  /// position taken at the previous outlet would break every future check-in
  /// here. On a weak signal that means failing -- which is why the failure is
  /// surfaced and blocks saving, instead of silently leaving nulls.
  Future<void> _captureLocation() async {
    if (_isResolvingAddress) return;
    setState(() {
      _isResolvingAddress = true;
      _locationError = null;
    });

    try {
      final position = await LocationService.getCurrentPosition(
        requireFresh: true,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;
      setState(() {
        _capturedLatitude = position.latitude;
        _capturedLongitude = position.longitude;
        _locationCapturedAt = DateTime.now();
        _isResolvingAddress = false;
      });

      // The address is a convenience, not a requirement -- resolving it is a
      // network round trip that used to hold the spinner after the fix had
      // already landed. Fill it in whenever it arrives.
      unawaited(_resolveAddress(position.latitude, position.longitude));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResolvingAddress = false;
        _capturedLatitude = null;
        _capturedLongitude = null;
        _locationCapturedAt = null;
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
      if (!mounted || resolved == null || resolved.isEmpty) return;
      // Never overwrite something the rep has typed themselves.
      if (_addressController.text.trim().isEmpty) {
        _addressController.text = resolved;
      }
    } catch (_) {
      // Address is optional; the coordinates are what matter.
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
        outletClassId: _selectedOutletClassId,
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

    final Color accent = hasFix
        ? AppColors.primary
        : (_isResolvingAddress ? AppColors.textSecondary : Colors.red.shade700);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFix ? AppColors.borderSoft : accent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasFix ? Icons.my_location : Icons.location_disabled,
            size: 20,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFix ? 'Outlet Location Captured' : 'Outlet Location *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: hasFix ? AppColors.textPrimary : accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasFix
                      ? 'Lat: ${_capturedLatitude!.toStringAsFixed(6)}, Lon: ${_capturedLongitude!.toStringAsFixed(6)}'
                      : _isResolvingAddress
                      ? 'Getting location…'
                      : (reason.isEmpty ? 'Not captured yet' : reason),
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
                      'Outlet Owner Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ownerNameController,
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
                        final classes = provider.outletClasses;
                        final types = provider.outletTypes;

                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Outlet Class *',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int>(
                                    value: _selectedOutletClassId,
                                    validator: (val) => val == null
                                        ? 'Outlet Class is required'
                                        : null,
                                    decoration: InputDecoration(
                                      hintText: classes.isEmpty
                                          ? 'No classes found'
                                          : 'Select Class',
                                      filled: true,
                                      fillColor: AppColors.borderMuted,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    items: classes.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c.id,
                                        child: Text(c.name),
                                      );
                                    }).toList(),
                                    onChanged: classes.isEmpty
                                        ? null
                                        : (val) {
                                            setState(() => _selectedOutletClassId = val);
                                          },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
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
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Route',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: widget.routeName,
                                readOnly: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.borderMuted,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DB Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: widget.distributorName,
                                readOnly: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.borderMuted,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
