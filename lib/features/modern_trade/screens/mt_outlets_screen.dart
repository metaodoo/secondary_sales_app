import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/util/proximity_helper.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_outlet.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_customer_action_bottom_sheet.dart';

class MtOutletsScreen extends StatefulWidget {
  const MtOutletsScreen({
    super.key,
    this.onBack,
    this.onOpenMenu,
    this.onProfileTap,
  });

  final VoidCallback? onBack;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onProfileTap;

  @override
  State<MtOutletsScreen> createState() => _MtOutletsScreenState();
}

class _MtOutletsScreenState extends State<MtOutletsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  StreamSubscription<Position>? _positionStreamSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ModernTradeProvider>();
      provider.fetchOutlets();
      provider.refreshGpsPosition(requireFresh: false);
    });

    _startLocationStream();
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
            context.read<ModernTradeProvider>().updateLocation(position);
          }
        },
        onError: (e) {
          debugPrint('Location stream error in MT screen: $e');
        },
      );
    } catch (e) {
      debugPrint('Could not initialize location stream: $e');
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openActionModalFor(MtOutlet outlet) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MtCustomerActionBottomSheet(outlet: outlet),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModernTradeProvider>();
    final outlets = provider.getSortedOutlets(searchQuery: _searchQuery);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'MT Outlets',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.onOpenMenu != null
            ? IconButton(
                onPressed: widget.onOpenMenu,
                icon: const Icon(Icons.menu, color: AppColors.primaryStrong),
              )
            : widget.onBack != null
            ? IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, color: AppColors.primaryStrong),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: ssInputDecoration(
                  'Search store name or code...',
                  Icons.search,
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
                      provider.toggleSortByNearest();
                      if (provider.sortByNearest && provider.currentPosition == null) {
                        provider.refreshGpsPosition(requireFresh: false);
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: provider.sortByNearest
                            ? AppColors.primaryStrong
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: provider.sortByNearest
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
                            color: provider.sortByNearest
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            provider.sortByNearest ? 'Nearest First' : 'Default Order',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: provider.sortByNearest
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
                    onTap: provider.isGpsRefreshing
                        ? null
                        : () async {
                            final pos = await provider.refreshGpsPosition(requireFresh: true);
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
                          if (provider.isGpsRefreshing)
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
                            provider.isGpsRefreshing ? 'Updating...' : 'Refresh GPS',
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
            const SizedBox(height: 4),
            Expanded(
              child: provider.isLoading && provider.outlets.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => provider.fetchOutlets(),
                      child: outlets.isEmpty
                          ? const Center(
                              child: Text(
                                'No Modern Trade outlets found.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: outlets.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final outlet = outlets[i];
                                final isCheckedIn = provider.checkedInOutletId == outlet.id || outlet.isActiveCheckedIn;

                                final distanceMeters = ProximityHelper.calculateDistance(
                                  userLat: provider.currentPosition?.latitude,
                                  userLng: provider.currentPosition?.longitude,
                                  outletLat: outlet.latitude,
                                  outletLng: outlet.longitude,
                                );

                                return GestureDetector(
                                  onTap: () => _openActionModalFor(outlet),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isCheckedIn ? const Color(0xFF10B981) : AppColors.borderSoft,
                                        width: isCheckedIn ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
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
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      outlet.name,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                  if (distanceMeters != null) ...[
                                                    _buildDistanceBadge(
                                                      distanceMeters,
                                                      outlet: outlet,
                                                      userPosition: provider.currentPosition,
                                                    ),
                                                    const SizedBox(width: 6),
                                                  ],
                                                  _buildBadge(outlet),
                                                ],
                                              ),
                                              if (outlet.ssCode != null && outlet.ssCode!.trim().isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Code: ${outlet.ssCode!.trim()}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                              if (outlet.street != null && outlet.street!.trim().isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        outlet.street!.trim(),
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors.textSecondary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceBadge(
    double distanceMeters, {
    required MtOutlet outlet,
    Position? userPosition,
  }) {
    final formatted = ProximityHelper.formatDistance(distanceMeters);
    return InkWell(
      onTap: () {
        ProximityHelper.openGoogleMapsDirections(
          context: context,
          destinationLat: outlet.latitude,
          destinationLng: outlet.longitude,
          originLat: userPosition?.latitude,
          originLng: userPosition?.longitude,
          destinationTitle: outlet.name,
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                fontWeight: FontWeight.w700,
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

  Widget _buildBadge(MtOutlet outlet) {
    if (outlet.isRecommended) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 12, color: Color(0xFF065F46)),
            SizedBox(width: 4),
            Text(
              'Recommended',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF065F46),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Allowed',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }
  }
}
