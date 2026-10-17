import 'package:flutter_test/flutter_test.dart';

/// Helper model replicating the screen logic for button visibility evaluation.
class ReturnButtonVisibilityEvaluator {
  final bool isTransitLeg;
  final String? returnReceiptStatus;
  final bool canSendToSalesOperation;
  final bool canValidate;

  ReturnButtonVisibilityEvaluator({
    required this.isTransitLeg,
    required this.returnReceiptStatus,
    required this.canSendToSalesOperation,
    required this.canValidate,
  });

  bool canShowSendToSalesOperation() {
    if (!canSendToSalesOperation) return false;
    if (!isTransitLeg) return false;
    return returnReceiptStatus == 'warehouse_receipt';
  }

  bool canShowValidate() {
    if (!canValidate) return false;
    if (isTransitLeg) {
      return returnReceiptStatus == 'sales_operation_receipt';
    }
    return true;
  }
}

void main() {
  group('Return & Scrap "Send to Sales Operation" and "Validate" Button Visibility', () {
    test('Leg 1 (PSR): "Send to Sales Operation" is NEVER shown even if user has permission', () {
      final evaluator = ReturnButtonVisibilityEvaluator(
        isTransitLeg: false,
        returnReceiptStatus: null,
        canSendToSalesOperation: true,
        canValidate: true,
      );

      expect(
        evaluator.canShowSendToSalesOperation(),
        isFalse,
        reason: 'Leg 1 moves distributor stock to transit; Send to Sales Operation belongs only to Leg 2.',
      );
      expect(
        evaluator.canShowValidate(),
        isTrue,
        reason: 'Leg 1 can be validated by authorized Sales Officer.',
      );
    });

    test('Leg 2 (PSRT) in warehouse_receipt: "Send to Sales Operation" is visible, "Validate" is hidden', () {
      final evaluator = ReturnButtonVisibilityEvaluator(
        isTransitLeg: true,
        returnReceiptStatus: 'warehouse_receipt',
        canSendToSalesOperation: true,
        canValidate: true,
      );

      expect(
        evaluator.canShowSendToSalesOperation(),
        isTrue,
        reason: 'Warehouse coordinator must see "Send to Sales Operation" while in warehouse_receipt.',
      );
      expect(
        evaluator.canShowValidate(),
        isFalse,
        reason: 'Leg 2 cannot be validated before warehouse hands off to Sales Operation.',
      );
    });

    test('Leg 2 (PSRT) after send to sales operation: "Send to Sales Operation" is HIDDEN (fixes bug)', () {
      final evaluator = ReturnButtonVisibilityEvaluator(
        isTransitLeg: true,
        returnReceiptStatus: 'sales_operation_receipt',
        canSendToSalesOperation: true,
        canValidate: true,
      );

      expect(
        evaluator.canShowSendToSalesOperation(),
        isFalse,
        reason: 'Once sent to Sales Operation, the button must disappear.',
      );
      expect(
        evaluator.canShowValidate(),
        isTrue,
        reason: 'Sales Operation can now review QC numbers and validate the transfer.',
      );
    });

    test('User without permission cannot see "Send to Sales Operation" regardless of status', () {
      final evaluator = ReturnButtonVisibilityEvaluator(
        isTransitLeg: true,
        returnReceiptStatus: 'warehouse_receipt',
        canSendToSalesOperation: false,
        canValidate: false,
      );

      expect(evaluator.canShowSendToSalesOperation(), isFalse);
      expect(evaluator.canShowValidate(), isFalse);
    });

    test('Leg 2 Scrap / Quality return exhibits identical state transitions', () {
      // Step 1: Arrives at warehouse in warehouse_receipt
      var scrapEvaluator = ReturnButtonVisibilityEvaluator(
        isTransitLeg: true,
        returnReceiptStatus: 'warehouse_receipt',
        canSendToSalesOperation: true,
        canValidate: true,
      );
      expect(scrapEvaluator.canShowSendToSalesOperation(), isTrue);
      expect(scrapEvaluator.canShowValidate(), isFalse);

      // Step 2: Warehouse sends to Sales Operation
      scrapEvaluator = ReturnButtonVisibilityEvaluator(
        isTransitLeg: true,
        returnReceiptStatus: 'sales_operation_receipt',
        canSendToSalesOperation: true,
        canValidate: true,
      );
      expect(scrapEvaluator.canShowSendToSalesOperation(), isFalse);
      expect(scrapEvaluator.canShowValidate(), isTrue);
    });
  });
}
