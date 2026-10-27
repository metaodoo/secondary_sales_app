import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondary_sales/features/hr/screens/attendance_screen.dart';

/// N27: an attendance log-out is one tap, so it must be confirmed first.
void main() {
  Future<bool?> answer(WidgetTester tester, String button) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await confirmAttendanceLogOut(context),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Log out of attendance?'), findsOneWidget);
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('Log Out confirms', (tester) async {
    expect(await answer(tester, 'Log Out'), isTrue);
  });

  testWidgets('Cancel does not log out', (tester) async {
    expect(await answer(tester, 'Cancel'), isFalse);
  });
}
