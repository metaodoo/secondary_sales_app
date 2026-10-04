import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/dashboard/screens/module_selection_screen.dart';

void main() {
  testWidgets('module selection shows primary and secondary options', (
    WidgetTester tester,
  ) async {
    final auth = AuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const ModuleSelectionScreen(),
        ),
      ),
    );

    expect(find.text('Select Module'), findsOneWidget);
    expect(
      find.text('Choose your operational flow to continue.'),
      findsOneWidget,
    );
  });
}
