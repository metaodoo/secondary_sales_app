import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/features/contacts/screens/edit_outlet_screen.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';

void main() {
  testWidgets('EditOutletScreen renders mandatory outlet photo section and triggers camera check', (tester) async {
    final outlet = {
      'id': 123,
      'name': 'Test Store',
      'owner_name': 'Test Owner',
      'mobile': '01700000000',
      'street': 'Test Street, Dhaka',
    };

    final routeProvider = RouteProvider();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<RouteProvider>.value(
          value: routeProvider,
          child: EditOutletScreen(outlet: outlet),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Outlet Photo section is rendered
    expect(find.text('Outlet Photo *'), findsOneWidget);
    expect(find.text('Take Outlet Photo *'), findsOneWidget);
    expect(find.text('Live camera photo required to update'), findsOneWidget);

    // Verify Update Outlet button exists
    final updateButton = find.widgetWithText(ElevatedButton, 'Update Outlet');
    expect(updateButton, findsOneWidget);
  });
}
