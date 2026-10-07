# Implementation Plan: Sales Officer Daily Master Data Offline Pre-Hydration & Two-Phase Sync Engine

**Spec Reference:** [`docs/superpowers/specs/2026-10-07-sales-officer-daily-master-data-offline-sync-design.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/docs/superpowers/specs/2026-10-07-sales-officer-daily-master-data-offline-sync-design.md)  
**Branch:** `MT_1.0`  
**Date:** 2026-10-07  

---

## Proposed Changes

### Task 1: SQLite Schema Upgrade (v2) in `OfflineDatabaseHelper`
- Upgrade database version from 1 to 2 in [`offline_database_helper.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/core/services/offline_database_helper.dart).
- Add `onUpgrade` handler to preserve all existing `outbox_operations` and `cached_master_data`.
- Create tables:
  - `local_distributors`
  - `local_routes`
  - `local_outlets`
  - `local_products_stock`
  - `local_distributor_stocks`
  - `local_vans`
  - `local_reference_metadata`
- Create indices for fast route/coords/code lookups.
- Implement CRUD & atomic mutation helper methods:
  - `saveLocalDistributors`, `getLocalDistributors`
  - `saveLocalRoutes`, `getLocalRoutes`
  - `saveLocalOutlets`, `getLocalOutlets(int? routeId, String? search)`
  - `saveLocalProducts`, `getLocalProducts`
  - `saveDistributorStocks`, `getDistributorStock(int distributorId, int productId)`
  - `saveLocalVans`, `getLocalVans`
  - `decrementLocalStock(int productId, double qty, {int? distributorId, bool isVan = true})`
  - `executeTransaction(Future<void> Function(Transaction txn) action)`

### Task 2: Implement `MasterDataSyncService` (Two-Phase Pipeline)
- Create `lib/core/services/master_data_sync_service.dart`:
  - `triggerDailySync({bool force = false})`
  - **Phase 1 Guard:** Wait for / call `OfflineSyncEngine.instance.processOutboxQueue()`. Verify 0 pending operations remain before proceeding.
  - **Phase 2 Inbound Hydration:**
    1. Fetch assigned distributors via `/api/v1/contacts` (`customer_type = 'distributor'`).
    2. Fetch assigned routes via `/api/v1/ss/routes`.
    3. For each route, fetch route detail & outlets via `/api/v1/ss/routes/<route_id>`.
    4. Fetch van locations via `/api/v1/virtual-locations`.
    5. For each distributor, fetch catalog & stock via `/api/v1/products` (`sale_type = 'secondary'`, `partner_id = distributor.id`).
    6. Fetch reference metadata (reasons) via `/api/v1/visits/reasons`.
  - Save all inbound data in an atomic SQLite `db.transaction()`.
  - Expose stream/notifier for UI sync status.

### Task 3: Background Timers, Lifecycle & FCM Delta Push Integration
- In [`auth_provider.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/features/auth/auth_provider.dart):
  - Trigger `MasterDataSyncService.instance.triggerDailySync()` upon login and token refresh.
- In [`offline_sync_engine.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/core/services/offline_sync_engine.dart):
  - Chain Phase 2 hydration immediately after Phase 1 outbox drain completes.
  - Add 15-minute periodic background timer when online.
- In [`push_notification_service.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/core/services/push_notification_service.dart):
  - Listen for `distributor_stock_delta` messages.
  - Update `local_distributor_stocks` via atomic SQL with 0 network calls.
  - Notify active providers.

### Task 4: Local-First Offline Integration in Screens & Providers
- In [`route_provider.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/features/routes/route_provider.dart):
  - Read from `local_routes` and `local_outlets` when network is unavailable.
- In [`primary_sale_provider.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/features/sales/primary_sale_provider.dart) & [`product_selection_screen.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/features/sales/screens/product_selection_screen.dart):
  - Fall back to `local_products_stock` and `local_distributor_stocks` when offline.
- In [`order_creation_screen.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/features/sales/screens/order_creation_screen.dart):
  - Read `dbStock` from `local_distributor_stocks` and `vanStock` from `local_products_stock`.
  - Prompt soft warning dialog if order exceeds remaining stock.
  - Decrement local stock in SQLite immediately upon order placement.

### Task 5: Verification & Automated Test Suite
- Write comprehensive tests in `test/master_data_offline_sync_test.dart`:
  - Test SQLite v2 upgrade and table creation.
  - Test Phase 1 -> Phase 2 sequencing.
  - Test local stock decrement & soft warning logic.
  - Test targeted FCM stock delta mutation.
- Run `flutter analyze` and `flutter test`.
- Git commit and push to `origin MT_1.0`.

---

## Verification Plan
1. **Automated Unit & Integration Tests:**
   - Execute `flutter test test/master_data_offline_sync_test.dart`.
   - Execute full test suite `flutter test`.
2. **Static Analysis:**
   - Execute `flutter analyze`.
3. **Git Hygiene:**
   - Verify all changes adhere to Odoo commit message standards.
