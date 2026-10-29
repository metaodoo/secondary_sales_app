import 'package:flutter_test/flutter_test.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_stock_audit.dart';

void main() {
  group('Modern Trade Models & Employee Mapping', () {
    test('MtStockAudit.fromMap parses employee information correctly', () {
      final json = {
        'id': 1,
        'name': 'SA/001',
        'type': 'opening_stock',
        'type_label': 'Opening Stock',
        'state': 'draft',
        'date': '2026-10-28T10:00:00Z',
        'employee': {
          'id': 42,
          'name': 'Alex Subordinate',
        },
        'outlet': {
          'id': 10,
          'name': 'Super Outlet 10',
          'ss_code': 'OUT-10',
        },
        'total_lines': 5,
        'total_stock_count': 150.0,
      };

      final audit = MtStockAudit.fromMap(json);
      expect(audit.id, 1);
      expect(audit.employeeId, 42);
      expect(audit.employeeName, 'Alex Subordinate');
      expect(audit.outletId, 10);
      expect(audit.outletName, 'Super Outlet 10');
      expect(audit.outletCode, 'OUT-10');
    });

    test('MtStockAudit.fromMap handles missing employee gracefully', () {
      final json = {
        'id': 2,
        'name': 'SA/002',
        'type': 'closing_stock',
        'state': 'confirm',
        'employee': null,
        'outlet': null,
      };

      final audit = MtStockAudit.fromMap(json);
      expect(audit.id, 2);
      expect(audit.employeeId, isNull);
      expect(audit.employeeName, isNull);
      expect(audit.outletId, isNull);
    });

    test('MtSecSaleOrder.fromMap parses employee and outlet correctly', () {
      final json = {
        'id': 50,
        'name': 'SEC/001',
        'state': 'done',
        'date': '2026-10-28T12:00:00Z',
        'employee': {
          'id': 55,
          'name': 'Sam Salesperson',
        },
        'outlet': {
          'id': 20,
          'name': 'Mega Mart',
          'ss_code': 'MM-20',
        },
        'total_lines': 3,
        'total_sold_qty': 45.0,
        'lines': [],
      };

      final order = MtSecSaleOrder.fromMap(json);
      expect(order.id, 50);
      expect(order.employeeId, 55);
      expect(order.employeeName, 'Sam Salesperson');
      expect(order.outletId, 20);
      expect(order.outletName, 'Mega Mart');
      expect(order.totalSoldQty, 45.0);
    });
  });

  group('Outlet Grouping Logic', () {
    test('Groups stock audits by outlet ID', () {
      final audits = [
        MtStockAudit(
          id: 1,
          name: 'SA/001',
          type: 'opening_stock',
          typeLabel: 'Opening Stock',
          state: 'draft',
          outletId: 10,
          outletName: 'Outlet A',
          employeeId: 42,
          employeeName: 'Alex',
        ),
        MtStockAudit(
          id: 2,
          name: 'SA/002',
          type: 'closing_stock',
          typeLabel: 'Closing Stock',
          state: 'confirm',
          outletId: 10,
          outletName: 'Outlet A',
          employeeId: 43,
          employeeName: 'Bob',
        ),
        MtStockAudit(
          id: 3,
          name: 'SA/003',
          type: 'stock_in',
          typeLabel: 'Stock In',
          state: 'confirm',
          outletId: 20,
          outletName: 'Outlet B',
          employeeId: 42,
          employeeName: 'Alex',
        ),
      ];

      final Map<int, int> outletAuditCounts = {};
      for (final a in audits) {
        if (a.outletId == null) continue;
        outletAuditCounts[a.outletId!] = (outletAuditCounts[a.outletId!] ?? 0) + 1;
      }

      expect(outletAuditCounts[10], 2);
      expect(outletAuditCounts[20], 1);
    });
  });
}
