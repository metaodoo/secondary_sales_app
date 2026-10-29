import 'package:flutter_test/flutter_test.dart';
import 'package:secondary_sales/features/routes/screens/officer_route_selection_screen.dart';

void main() {
  group('sortRoutesByRecommendation', () {
    test('places recommended routes planned for today at the top', () {
      final routes = [
        {
          'id': 1,
          'name': 'Route Alpha (Not Planned)',
          'planned_days': ['1', '2'],
        },
        {
          'id': 2,
          'name': 'Route Beta (Planned Today)',
          'planned_days': ['3', '4'],
        },
        {
          'id': 3,
          'name': 'Route Gamma (Not Planned)',
          'planned_days': [],
        },
      ];

      // Assuming today is Thursday: Odoo weekday "3"
      final sorted = sortRoutesByRecommendation(routes, '3');

      expect(sorted.length, 3);
      expect(sorted[0]['id'], 2); // Route Beta at top
      expect(sorted[1]['id'], 1); // Alpha then Gamma alphabetically
      expect(sorted[2]['id'], 3);
    });

    test('sorts multiple recommended routes alphabetically', () {
      final routes = [
        {
          'id': 1,
          'name': 'Zone Z (Planned Today)',
          'planned_days': ['3'],
        },
        {
          'id': 2,
          'name': 'Zone A (Planned Today)',
          'planned_days': ['3'],
        },
        {
          'id': 3,
          'name': 'Zone M (Not Planned)',
          'planned_days': ['0'],
        },
      ];

      final sorted = sortRoutesByRecommendation(routes, '3');

      expect(sorted.length, 3);
      expect(sorted[0]['id'], 2); // Zone A first among recommended
      expect(sorted[1]['id'], 1); // Zone Z second among recommended
      expect(sorted[2]['id'], 3); // Zone M last
    });

    test('handles integer and string day_of_week representations safely', () {
      final routes = [
        {
          'id': 10,
          'name': 'Route With Int Days',
          'planned_days': [3, 5],
        },
        {
          'id': 20,
          'name': 'Route With String Days',
          'planned_days': ['1', '2'],
        },
      ];

      final sorted = sortRoutesByRecommendation(routes, '3');

      expect(sorted.first['id'], 10);
    });

    test('handles empty or null fields gracefully', () {
      final routes = <Map<String, dynamic>>[
        {'id': 1, 'name': null, 'planned_days': null},
        {'id': 2, 'name': 'Valid Route', 'planned_days': ['3']},
      ];

      final sorted = sortRoutesByRecommendation(routes, '3');

      expect(sorted.first['id'], 2);
    });
  });
}
