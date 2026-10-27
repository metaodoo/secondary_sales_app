import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/services/location_service.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/util/proximity_helper.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_outlet.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen displaying comprehensive Modern Trade Outlet details.
class MtOutletDetailScreen extends StatefulWidget {
  final int outletId;
  final MtOutlet? initialOutlet;

  const MtOutletDetailScreen({
    super.key,
    required this.outletId,
    this.initialOutlet,
  });

  @override
  State<MtOutletDetailScreen> createState() => _MtOutletDetailScreenState();
}

class _MtOutletDetailScreenState extends State<MtOutletDetailScreen> {
  bool _isLoading = true;
  bool _isRecalibratingGps = false;
  Map<String, dynamic> _contactData = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetails();
    });
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ModernTradeProvider>();
      final data = await provider.fetchOutletDetail(widget.outletId);

      if (!mounted) return;

      setState(() {
        _contactData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load outlet details: $e')),
        );
      }
    }
  }

  Future<void> _handleRecalibrateLocation() async {
    if (_isRecalibratingGps) return;

    final outletName = _contactData['name']?.toString() ?? widget.initialOutlet?.name ?? 'Outlet';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_location_alt_outlined, color: AppColors.primaryStrong),
            SizedBox(width: 8),
            Text('Update GPS Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you currently physically standing at "$outletName"?\n\n'
          'This will overwrite the outlet\'s saved coordinates with your current high-precision GPS position so future check-ins will work accurately.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStrong,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isRecalibratingGps = true);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Acquiring high-accuracy satellite GPS fix…'),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );

      final position = await LocationService.getAccuratePosition(
        desiredAccuracyInMeters: 25.0,
        maxAcceptableAccuracyInMeters: 35.0,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;

      final provider = context.read<ModernTradeProvider>();
      final result = await provider.updateOutletLocation(
        widget.outletId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location updated to ±${position.accuracy.round()}m accuracy! You can now check in.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadDetails();
      } else {
        throw Exception(provider.error ?? 'Failed to update location');
      }
    } catch (e) {
      if (mounted) {
        ssShowLocationErrorDialog(
          context,
          'Could not calibrate GPS: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRecalibratingGps = false);
      }
    }
  }

  Future<void> _makeCall(String? number) async {
    if (number == null || number.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number recorded for this outlet')),
      );
      return;
    }
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outletName = _contactData['name']?.toString() ?? widget.initialOutlet?.name ?? 'Outlet Details';
    final ssCode = _contactData['ss_code']?.toString() ?? widget.initialOutlet?.ssCode ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'MT Outlet Details',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryStrong),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryStrong),
            tooltip: 'Refresh',
            onPressed: _loadDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildViewDetails(outletName, ssCode),
            ),
    );
  }

  Widget _buildViewDetails(String outletName, String ssCode) {
    final provider = context.watch<ModernTradeProvider>();
    final lat = (_contactData['partner_latitude'] as num?)?.toDouble() ?? widget.initialOutlet?.latitude;
    final lng = (_contactData['partner_longitude'] as num?)?.toDouble() ?? widget.initialOutlet?.longitude;
    final outletRadius = (_contactData['outlet_radius'] as num?)?.toDouble() ?? widget.initialOutlet?.outletRadius ?? 50.0;

    double? distanceMeters;
    if (lat != null && lng != null && provider.currentPosition != null) {
      distanceMeters = ProximityHelper.calculateDistance(
        userLat: provider.currentPosition!.latitude,
        userLng: provider.currentPosition!.longitude,
        outletLat: lat,
        outletLng: lng,
      );
    }

    final ownerName = _contactData['owner_name']?.toString() ??
        _contactData['outlet_owner_name']?.toString() ??
        _contactData['contact_person']?.toString() ??
        '';

    final mobile = _contactData['mobile']?.toString() ?? '';
    final phone = _contactData['phone']?.toString() ?? widget.initialOutlet?.phone ?? '';
    final email = _contactData['email']?.toString() ?? '';

    String? typeName;
    if (_contactData['outlet_type'] is Map) {
      typeName = _contactData['outlet_type']['name']?.toString();
    } else if (_contactData['outlet_type_name'] != null) {
      typeName = _contactData['outlet_type_name'].toString();
    }

    String? className;
    if (_contactData['outlet_class'] is Map) {
      className = _contactData['outlet_class']['name']?.toString();
    } else if (_contactData['outlet_class_name'] != null) {
      className = _contactData['outlet_class_name'].toString();
    }

    String? chainShopName;
    if (_contactData['chain_shop_id'] is List && (_contactData['chain_shop_id'] as List).length > 1) {
      chainShopName = (_contactData['chain_shop_id'] as List)[1]?.toString();
    } else if (_contactData['chain_shop_name'] != null) {
      chainShopName = _contactData['chain_shop_name'].toString();
    }

    final street = _contactData['street']?.toString() ?? widget.initialOutlet?.street ?? '';
    final city = _contactData['city']?.toString() ?? '';
    final zip = _contactData['zip']?.toString() ?? '';
    final vat = _contactData['vat']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Store Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.storefront,
                      color: AppColors.primaryStrong,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          outletName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (ssCode.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Code: $ssCode',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryStrong,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Action Buttons Row: Call, Directions, Update GPS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: phone.isNotEmpty || mobile.isNotEmpty
                          ? () => _makeCall(mobile.isNotEmpty ? mobile : phone)
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderSoft),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.phone_outlined, size: 18, color: AppColors.primaryStrong),
                      label: const Text(
                        'Call',
                        style: TextStyle(color: AppColors.primaryStrong, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (lat != null && lng != null)
                          ? () {
                              ProximityHelper.openGoogleMapsDirections(
                                context: context,
                                destinationLat: lat,
                                destinationLng: lng,
                                originLat: provider.currentPosition?.latitude,
                                originLng: provider.currentPosition?.longitude,
                                destinationTitle: outletName,
                              );
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderSoft),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.directions_outlined, size: 18, color: Color(0xFF2563EB)),
                      label: const Text(
                        'Directions',
                        style: TextStyle(color: Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isRecalibratingGps ? null : _handleRecalibrateLocation,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderSoft),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: _isRecalibratingGps
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_location_alt_outlined, size: 18, color: Color(0xFF0284C7)),
                      label: const Text(
                        'GPS',
                        style: TextStyle(color: Color(0xFF0284C7), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Section: Contact & Management
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_outline, size: 18, color: AppColors.primaryStrong),
                  SizedBox(width: 8),
                  Text(
                    'CONTACT & MANAGEMENT',
                    style: TextStyle(
                      color: AppColors.primaryStrong,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoRow('Manager / Contact Person', ownerName.isNotEmpty ? ownerName : '—'),
              _buildInfoRow('Mobile', mobile.isNotEmpty ? mobile : '—'),
              _buildInfoRow('Phone', phone.isNotEmpty ? phone : '—'),
              _buildInfoRow('Email', email.isNotEmpty ? email : '—'),
              if (chainShopName != null && chainShopName.isNotEmpty)
                _buildInfoRow('Chain / Group', chainShopName),
              _buildInfoRow('Outlet Type', typeName ?? '—'),
              _buildInfoRow('Outlet Class', className ?? '—'),
              if (vat.isNotEmpty) _buildInfoRow('BIN / VAT', vat),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Section: Address & Location
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 18, color: AppColors.primaryStrong),
                  SizedBox(width: 8),
                  Text(
                    'LOCATION & ADDRESS',
                    style: TextStyle(
                      color: AppColors.primaryStrong,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoRow('Street Address', street.isNotEmpty ? street : '—'),
              if (city.isNotEmpty) _buildInfoRow('City / Area', city),
              if (zip.isNotEmpty) _buildInfoRow('Postal / Zip Code', zip),
              _buildInfoRow(
                'Coordinates',
                (lat != null && lng != null)
                    ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                    : 'Not set (Calibrate GPS)',
              ),
              if (distanceMeters != null)
                _buildInfoRow('Distance to Outlet', ProximityHelper.formatDistance(distanceMeters)),
              _buildInfoRow('Allowed Radius', '${outletRadius.round()} meters'),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
