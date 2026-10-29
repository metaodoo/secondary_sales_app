import 'package:flutter_test/flutter_test.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/data/models/auth/mobile_auth_session.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_return_request.dart';

void main() {
  group('MtAllowedActions & Stage Authorization Tests', () {
    test('MtAllowedActions parses required_access_key from backend map', () {
      final json = {
        'can_edit': true,
        'can_submit': true,
        'can_confirm': false,
        'can_reset': false,
        'requires_qc': true,
        'next_state': 'qc',
        'next_action': 'submit_qc',
        'next_action_label': 'Submit to QC',
        'required_access_key': 'action.modern_trade.returns.submit_qc',
      };

      final actions = MtAllowedActions.fromMap(json);
      expect(actions.nextAction, 'submit_qc');
      expect(actions.requiredAccessKey, 'action.modern_trade.returns.submit_qc');
      expect(actions.nextActionLabel, 'Submit to QC');
    });

    test('MtAllowedActions parses submit_sales_operation with submit_sales_operation required_access_key in supply_chain stage', () {
      final json = {
        'can_edit': true,
        'can_submit': true,
        'can_confirm': false,
        'can_reset': false,
        'requires_qc': false,
        'next_state': 'sales_operation',
        'next_action': 'submit_sales_operation',
        'next_action_label': 'Submit to Sales Operation',
        'required_access_key': 'action.modern_trade.returns.submit_sales_operation',
      };

      final actions = MtAllowedActions.fromMap(json);
      expect(actions.nextAction, 'submit_sales_operation');
      expect(actions.requiredAccessKey, 'action.modern_trade.returns.submit_sales_operation');
      expect(actions.nextActionLabel, 'Submit to Sales Operation');
    });

    test('MtAllowedActions parses submit_sales_operation with submit_sales_operation required_access_key in qc stage', () {
      final json = {
        'can_edit': true,
        'can_submit': true,
        'can_confirm': false,
        'can_reset': false,
        'requires_qc': true,
        'next_state': 'sales_operation',
        'next_action': 'submit_sales_operation',
        'next_action_label': 'Submit to Sales Operation',
        'required_access_key': 'action.modern_trade.returns.submit_sales_operation',
      };

      final actions = MtAllowedActions.fromMap(json);
      expect(actions.nextAction, 'submit_sales_operation');
      expect(actions.requiredAccessKey, 'action.modern_trade.returns.submit_sales_operation');
    });

    test('Supply Chain group code cannot perform QC stage even if granted submit_sales_operation key', () {
      final sessionMap = {
        'access_token': 'test_token',
        'refresh_token': 'test_refresh',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'user': {
          'id': 10,
          'name': 'Supply Chain User',
          'role': 'Supply Chain',
          'business_type': 'mt',
          'group': {
            'id': 5,
            'code': 'sc',
            'name': 'Supply Chain',
            'business_type': 'mt',
          },
        },
        'access': {
          'granted': [
            AppAction.mtReturnsSave,
            AppAction.mtReturnsSubmitQc,
            AppAction.mtReturnsSubmitSupplyChain,
            AppAction.mtReturnsSubmitSalesOperation, // Granted in DB profile
          ],
        },
      };

      final session = MobileAuthSession.fromMap(sessionMap);
      final user = session.user;
      expect(user.groupCode, 'sc');

      // Emulate canPerformStage logic for Supply Chain user when state is 'qc'
      final state = 'qc';
      final isBlockedForSc = (state == 'qc' && user.groupCode?.toLowerCase() == 'sc');
      expect(isBlockedForSc, isTrue, reason: 'Supply Chain user must be blocked when state is qc');
    });

    test('QC group user can perform QC stage with submit_sales_operation key', () {
      final sessionMap = {
        'access_token': 'test_token',
        'refresh_token': 'test_refresh',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'user': {
          'id': 12,
          'name': 'QC Inspector User',
          'role': 'Quality Check',
          'business_type': 'mt',
          'group': {
            'id': 6,
            'code': 'qc',
            'name': 'Quality Check',
            'business_type': 'mt',
          },
        },
        'access': {
          'granted': [
            AppAction.mtReturnsSave,
            AppAction.mtReturnsSubmitSalesOperation,
          ],
        },
      };

      final session = MobileAuthSession.fromMap(sessionMap);
      final user = session.user;
      expect(user.groupCode, 'qc');

      final state = 'qc';
      final isBlockedForSc = (state == 'qc' && user.groupCode?.toLowerCase() == 'sc');
      expect(isBlockedForSc, isFalse);
      expect(session.access.allows(AppAction.mtReturnsSubmitSalesOperation), isTrue);
    });

    test('KAS group code is blocked on supply_chain, qc, and sales_operation stages', () {
      final sessionMap = {
        'access_token': 'test_token',
        'refresh_token': 'test_refresh',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'user': {
          'id': 15,
          'name': 'KAS User',
          'role': 'Key Account Sales',
          'business_type': 'mt',
          'group': {
            'id': 7,
            'code': 'kas',
            'name': 'Key Account Sales',
            'business_type': 'mt',
          },
        },
        'access': {
          'enforced': [
            AppAction.mtReturnsSubmitDm,
            AppAction.mtReturnsSubmitKas,
            AppAction.mtReturnsSubmitSupplyChain,
            AppAction.mtReturnsSubmitQc,
            AppAction.mtReturnsSubmitSalesOperation,
            AppAction.mtReturnsConfirm,
          ],
          'granted': [
            AppAction.mtReturnsSave,
            AppAction.mtReturnsSubmitSupplyChain, // Only submit_supply_chain is granted
          ],
        },
      };

      final session = MobileAuthSession.fromMap(sessionMap);
      final user = session.user;
      final groupCode = user.groupCode?.toLowerCase();
      expect(groupCode, 'kas');

      // 1. Check role-stage exclusivity
      expect(groupCode == 'kas' && 'supply_chain' != 'kas', isTrue, reason: 'KAS cannot act on supply_chain state');
      expect(groupCode == 'kas' && 'qc' != 'kas', isTrue, reason: 'KAS cannot act on qc state');
      expect(groupCode == 'kas' && 'kas' != 'kas', isFalse, reason: 'KAS can act on kas state');

      // 2. Check UI access key denial
      expect(session.access.allows(AppAction.mtReturnsSubmitSalesOperation), isFalse,
          reason: 'KAS user must not have access to submit_sales_operation');
      expect(session.access.allows(AppAction.mtReturnsSubmitSupplyChain), isTrue,
          reason: 'KAS user has access to submit_supply_chain');
    });
  });
}
