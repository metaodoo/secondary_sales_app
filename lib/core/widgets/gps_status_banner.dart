import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:secondary_sales/core/services/gps_lock_service.dart';

/// A sleek, non-intrusive in-screen banner displaying GPS GNSS satellite lock
/// status on GPS-critical screens. Only repaints itself via [ValueListenableBuilder]
/// and never causes parent screen or list invalidations.
class GpsStatusBanner extends StatelessWidget {
  final ValueNotifier<GpsLockState> lockStateNotifier;
  final VoidCallback? onRefresh;
  final bool autoHideWhenLocked;

  const GpsStatusBanner({
    super.key,
    required this.lockStateNotifier,
    this.onRefresh,
    this.autoHideWhenLocked = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GpsLockState>(
      valueListenable: lockStateNotifier,
      builder: (context, state, _) {
        if (state.status == GpsLockStatus.locked && autoHideWhenLocked) {
          // Compact, subtle indicator when locked
          final acc = state.accuracy != null ? ' (±${state.accuracy!.round()}m)' : '';
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gps_fixed, size: 13, color: Colors.green),
                const SizedBox(width: 5),
                Text(
                  'GPS Locked$acc',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          );
        }

        if (state.status == GpsLockStatus.acquiring) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200, width: 0.8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.message ?? 'Acquiring GPS satellite lock...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (state.status == GpsLockStatus.weak) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB), // Amber 50
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1), // Amber 200
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFFD97706), // Amber 600
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.message ??
                        'Weak GPS signal. Step outside the canopy for accurate distance & check-in.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF92400E), // Amber 800
                    ),
                  ),
                ),
                if (onRefresh != null)
                  InkWell(
                    onTap: onRefresh,
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.refresh,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        if (state.status == GpsLockStatus.disabled) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.location_off, size: 16, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.message ?? 'Device location is turned off.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Geolocator.openLocationSettings(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('ENABLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          );
        }

        if (state.status == GpsLockStatus.denied) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.message ?? 'Location permission required.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Geolocator.openAppSettings(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
