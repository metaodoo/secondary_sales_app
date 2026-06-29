import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/dashboard/screens/module_selection_screen.dart';

void main() {
  testWidgets('module selection shows primary and secondary options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const ModuleSelectionScreen()),
    );

    expect(find.text('Select Module'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Secondary'), findsOneWidget);

    expect(find.byIcon(Icons.factory_outlined), findsOneWidget);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
  });
}
