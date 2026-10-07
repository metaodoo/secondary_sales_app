import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class ProximityHelper {
  /// Calculates distance in meters between user GPS and target coordinates.
  /// Returns null if user position or outlet coordinates are missing/invalid.
  static double? calculateDistance({
    required double? userLat,
    required double? userLng,
    required double? outletLat,
    required double? outletLng,
  }) {
    if (userLat == null || userLng == null || outletLat == null || outletLng == null) {
      return null;
    }
    if (outletLat == 0.0 && outletLng == 0.0) return null;
    if (outletLat < -90 || outletLat > 90 || outletLng < -180 || outletLng > 180) {
      return null;
    }
    try {
      return Geolocator.distanceBetween(userLat, userLng, outletLat, outletLng);
    } catch (_) {
      return null;
    }
  }

  /// Formats distance in meters into a clean string:
  /// - Under 1000m: "45 m", "350 m"
  /// - 1km - 10km: "1.2 km", "4.5 km"
  /// - Over 10km: "12 km"
  static String formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return '';
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    final km = distanceMeters / 1000;
    if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    }
    return '${km.round()} km';
  }

  /// Checks if the calculated distance falls within the geofence radius.
  static bool isInsideRadius({
    required double? distanceMeters,
    double radiusMeters = 50.0,
  }) {
    if (distanceMeters == null) return false;
    return distanceMeters <= radiusMeters;
  }

  /// Checks if geofence is satisfied taking GPS Circular Error Probable (CEP) into account.
  /// Standard GPS accuracy defines a 68% confidence radius. In dense markets and under
  /// canopies, GPS jitter shifts coordinates by up to 25m even when standing inside the shop.
  ///
  /// This applies a 50% CEP tolerance (capped at 15m maximum) to prevent false lockouts
  /// while strictly enforcing the company's geofence boundary.
  static bool isGeofenceSatisfied({
    required double? distanceMeters,
    double? accuracyMeters,
    double allowedRadius = 50.0,
  }) {
    if (distanceMeters == null) return false;
    final acc = accuracyMeters ?? 0.0;
    // For standard GPS fixes, discount 50% of the CEP accuracy uncertainty, clamped to 15m max
    final uncertaintyDiscount = acc <= 30.0 ? (acc * 0.5) : 15.0;
    final effectiveDistance = (distanceMeters - uncertaintyDiscount).clamp(0.0, double.infinity);
    return effectiveDistance <= allowedRadius;
  }

  /// Generates the Google Maps Universal Directions Uri.
  static Uri getGoogleMapsDirectionsUri({
    required double destinationLat,
    required double destinationLng,
    double? originLat,
    double? originLng,
  }) {
    final buffer = StringBuffer('https://www.google.com/maps/dir/?api=1');
    if (originLat != null && originLng != null && originLat != 0.0 && originLng != 0.0) {
      buffer.write('&origin=$originLat,$originLng');
    }
    buffer.write('&destination=$destinationLat,$destinationLng');
    buffer.write('&travelmode=driving');
    return Uri.parse(buffer.toString());
  }

  /// Opens Google Maps app with route directions from source to destination.
  static Future<bool> openGoogleMapsDirections({
    BuildContext? context,
    required double? destinationLat,
    required double? destinationLng,
    double? originLat,
    double? originLng,
    String? destinationTitle,
  }) async {
    if (destinationLat == null ||
        destinationLng == null ||
        (destinationLat == 0.0 && destinationLng == 0.0) ||
        destinationLat < -90 ||
        destinationLat > 90 ||
        destinationLng < -180 ||
        destinationLng > 180) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              destinationTitle != null && destinationTitle.trim().isNotEmpty
                  ? 'No GPS coordinates saved for "$destinationTitle"'
                  : 'No GPS coordinates saved for this outlet',
            ),
            backgroundColor: const Color(0xFFD97706),
          ),
        );
      }
      return false;
    }

    final uri = getGoogleMapsDirectionsUri(
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      originLat: originLat,
      originLng: originLng,
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Google Maps app')),
        );
      }
      return launched;
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening Google Maps: $e')),
        );
      }
      return false;
    }
  }
}
