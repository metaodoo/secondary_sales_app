import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

void main() {
  group('SmallStepper and SSQtyField quantity updates with focus', () {
    testWidgets('SmallStepper updates text field when plus/minus tapped even if focused', (tester) async {
      int qty = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SmallStepper(
                  value: qty.toString(),
                  onMinus: () {
                    setState(() => qty--);
                  },
                  onPlus: () {
                    setState(() => qty++);
                  },
                  onValueInput: (val) {
                    setState(() => qty = int.tryParse(val) ?? qty);
                  },
                );
              },
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      expect(find.text('1'), findsOneWidget);

      // Focus the text field
      await tester.tap(textField);
      await tester.pump();
      expect(tester.widget<TextField>(textField).focusNode!.hasFocus, isTrue);

      // Tap plus button
      final plusButton = find.byIcon(Icons.add);
      await tester.tap(plusButton);
      await tester.pump();

      // Verify the controller and UI updated to 2
      expect(tester.widget<TextField>(textField).controller!.text, '2');
      expect(qty, 2);

      // Tap minus button
      final minusButton = find.byIcon(Icons.remove);
      await tester.tap(minusButton);
      await tester.pump();

      // Verify the controller and UI updated to 1
      expect(tester.widget<TextField>(textField).controller!.text, '1');
      expect(qty, 1);
    });

    testWidgets('SSQtyField updates controller text when value changes from external +/- even if focused', (tester) async {
      int qty = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Row(
                  children: [
                    SSQtyField(
                      value: qty.toString(),
                      onChanged: (val) {
                        setState(() => qty = int.tryParse(val) ?? qty);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () => setState(() => qty--),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => qty++),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      expect(tester.widget<TextField>(textField).controller!.text, '1');

      // Focus the text field
      await tester.tap(textField);
      await tester.pump();

      // Tap plus button
      final plusButton = find.byIcon(Icons.add);
      await tester.tap(plusButton);
      await tester.pump();

      // Text should reflect new value '2'
      expect(tester.widget<TextField>(textField).controller!.text, '2');

      // Tap minus button
      final minusButton = find.byIcon(Icons.remove);
      await tester.tap(minusButton);
      await tester.pump();

      // Text should reflect new value '1'
      expect(tester.widget<TextField>(textField).controller!.text, '1');
    });
  });
}
