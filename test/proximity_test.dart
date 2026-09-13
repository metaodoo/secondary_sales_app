import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:secondary_sales/core/util/proximity_helper.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_outlet.dart';
import 'package:secondary_sales/data/models/routes/route.dart';
import 'package:secondary_sales/features/modern_trade/modern_trade_provider.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';

void main() {
  group('ProximityHelper Tests', () {
    test('calculateDistance returns null for invalid / missing coordinates', () {
      expect(
        ProximityHelper.calculateDistance(
          userLat: null,
          userLng: 90.4125,
          outletLat: 23.8103,
          outletLng: 90.4125,
        ),
        isNull,
      );

      expect(
        ProximityHelper.calculateDistance(
          userLat: 23.8103,
          userLng: 90.4125,
          outletLat: 0.0,
          outletLng: 0.0,
        ),
        isNull,
      );

      expect(
        ProximityHelper.calculateDistance(
          userLat: 23.8103,
          userLng: 90.4125,
          outletLat: 95.0,
          outletLng: 90.4125,
        ),
        isNull,
      );
    });

    test('calculateDistance calculates geodesic distance correctly', () {
      // Dhaka Gulshan-1 to Gulshan-2 approx 1.5 km
      final dist = ProximityHelper.calculateDistance(
        userLat: 23.7786,
        userLng: 90.4172,
        outletLat: 23.7925,
        outletLng: 90.4078,
      );

      expect(dist, isNotNull);
      expect(dist!, greaterThan(1400));
      expect(dist, lessThan(2000));
    });

    test('formatDistance formats meters and kilometers accurately', () {
      expect(ProximityHelper.formatDistance(null), '');
      expect(ProximityHelper.formatDistance(45.4), '45 m');
      expect(ProximityHelper.formatDistance(350.0), '350 m');
      expect(ProximityHelper.formatDistance(999.0), '999 m');
      expect(ProximityHelper.formatDistance(1200.0), '1.2 km');
      expect(ProximityHelper.formatDistance(4600.0), '4.6 km');
      expect(ProximityHelper.formatDistance(12400.0), '12 km');
    });

    test('isInsideRadius tests geofence threshold', () {
      expect(ProximityHelper.isInsideRadius(distanceMeters: null), false);
      expect(ProximityHelper.isInsideRadius(distanceMeters: 30.0, radiusMeters: 50.0), true);
      expect(ProximityHelper.isInsideRadius(distanceMeters: 50.0, radiusMeters: 50.0), true);
      expect(ProximityHelper.isInsideRadius(distanceMeters: 50.1, radiusMeters: 50.0), false);
    });

    test('getGoogleMapsDirectionsUri builds correct universal directions URL', () {
      final uriWithOrigin = ProximityHelper.getGoogleMapsDirectionsUri(
        destinationLat: 23.7925,
        destinationLng: 90.4078,
        originLat: 23.7786,
        originLng: 90.4172,
      );

      expect(uriWithOrigin.toString(), 'https://www.google.com/maps/dir/?api=1&origin=23.7786,90.4172&destination=23.7925,90.4078&travelmode=driving');

      final uriWithoutOrigin = ProximityHelper.getGoogleMapsDirectionsUri(
        destinationLat: 23.7925,
        destinationLng: 90.4078,
      );

      expect(uriWithoutOrigin.toString(), 'https://www.google.com/maps/dir/?api=1&destination=23.7925,90.4078&travelmode=driving');
    });

    test('openGoogleMapsDirections validates destination coordinates safely', () async {
      expect(
        await ProximityHelper.openGoogleMapsDirections(
          destinationLat: null,
          destinationLng: 90.4078,
        ),
        false,
      );

      expect(
        await ProximityHelper.openGoogleMapsDirections(
          destinationLat: 0.0,
          destinationLng: 0.0,
        ),
        false,
      );

      expect(
        await ProximityHelper.openGoogleMapsDirections(
          destinationLat: 95.0,
          destinationLng: 90.4078,
        ),
        false,
      );
    });
  });

  group('ModernTradeProvider Proximity Sorting Tests', () {
    test('sorts outlets by nearest GPS location with active check-in pinned at top', () {
      final provider = ModernTradeProvider();

      final outletFar = MtOutlet(
        id: 1,
        name: 'Far Store',
        latitude: 23.9000,
        longitude: 90.4500,
      );
      final outletNear = MtOutlet(
        id: 2,
        name: 'Near Store',
        latitude: 23.7790,
        longitude: 90.4175,
      );
      final outletNoCoords = MtOutlet(
        id: 3,
        name: 'No GPS Store',
      );
      final outletCheckedIn = MtOutlet(
        id: 4,
        name: 'Active Checked In Store',
        latitude: 23.9900,
        longitude: 90.5000,
        isActiveCheckedIn: true,
      );

      // Populate provider internal list
      provider.outlets.addAll([outletFar, outletNear, outletNoCoords, outletCheckedIn]);

      // Set user position close to Near Store (23.7786, 90.4172)
      final userPos = Position(
        latitude: 23.7786,
        longitude: 90.4172,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );
      provider.updateLocation(userPos);

      // Default sorting (sortByNearest = false)
      final defaultList = provider.getSortedOutlets();
      expect(defaultList.first.id, 4); // Active checked in pinned to top

      // Enable Sort by Nearest
      provider.setSortByNearest(true);
      final sortedList = provider.getSortedOutlets();

      expect(sortedList.length, 4);
      expect(sortedList[0].id, 4); // Checked in outlet remains pinned at index 0
      expect(sortedList[1].id, 2); // Near store is closest (~50-100m)
      expect(sortedList[2].id, 1); // Far store
      expect(sortedList[3].id, 3); // No coordinates store placed at end
    });
  });

  group('RouteProvider Proximity Sorting Tests', () {
    test('sorts route outlets by nearest location and maintains sequence when disabled', () {
      final provider = RouteProvider();

      final outlet1 = RouteOutlet(
        lineId: 10,
        id: 1,
        name: 'Outlet Alpha (Far)',
        sequence: 1,
        expectedVisitTime: 15.0,
        active: true,
        partnerLatitude: 23.9500,
        partnerLongitude: 90.5000,
      );
      final outlet2 = RouteOutlet(
        lineId: 20,
        id: 2,
        name: 'Outlet Beta (Near)',
        sequence: 2,
        expectedVisitTime: 15.0,
        active: true,
        partnerLatitude: 23.7790,
        partnerLongitude: 90.4175,
      );
      final outlet3 = RouteOutlet(
        lineId: 30,
        id: 3,
        name: 'Outlet Gamma (No Coords)',
        sequence: 3,
        expectedVisitTime: 15.0,
        active: true,
      );

      final userPos = Position(
        latitude: 23.7786,
        longitude: 90.4172,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );
      provider.updateLocation(userPos);

      final outlets = [outlet1, outlet2, outlet3];

      // Default sequence order
      provider.setSortByNearest(false);
      final seqList = provider.getSortedRouteOutlets(outlets);
      expect(seqList[0].id, 1);
      expect(seqList[1].id, 2);
      expect(seqList[2].id, 3);

      // Nearest first order
      provider.setSortByNearest(true);
      final nearestList = provider.getSortedRouteOutlets(outlets);
      expect(nearestList[0].id, 2); // Beta is nearest
      expect(nearestList[1].id, 1); // Alpha
      expect(nearestList[2].id, 3); // Gamma (no coords at end)
    });
  });
}
