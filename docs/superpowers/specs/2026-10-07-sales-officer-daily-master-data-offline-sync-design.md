# Design Specification: Sales Officer Daily Master Data Offline Pre-Hydration & Two-Phase Sync Engine

**Date:** 2026-10-07  
**Status:** Approved  
**Scope:** GDFL Secondary Sales Mobile App (`secondary_sales_app` / branch `MT_1.0`)  
**Target Backend:** Odoo 18 Enterprise (`gdfl_v18_sh` / `meta_ss_rest_api` / `meta_ss_route_management`)

---

## 1. Overview & Objective

In field sales operations across regional Bangladesh, sales officers frequently operate in remote, low-connectivity, or completely offline markets. 

Previously, the app relied on opportunistic / reactive caching (only saving data if a user happened to navigate to that specific screen while online). If an officer logged in and drove into a market without opening every route and product list beforehand, the app had no local data to display, rendering offline booking impossible.

This specification establishes a **proactive, daily-scoped offline master data pre-hydration engine** combined with **local-first event-driven inventory mutations** and a **strictly ordered two-phase synchronization pipeline**.

---

## 2. Core Architectural Principles

1. **Shift Kickoff Pre-Hydration**: Upon login or shift start, the system automatically fetches all master data required specifically for that sales officer's daily work (assigned distributors, assigned routes, outlets, van locations, product catalog, and van/distributor stock levels) into dedicated SQLite tables.
2. **Local-First Event-Driven Mutation**: User actions (secondary sales orders, returns, scraps, check-ins) immediately mutate local SQLite state and update the UI in 0ms, buffering the outbound write into SQLite `outbox_operations`.
3. **Outbox-First Synchronization Ordering**: When synchronizing with Odoo, **Phase 1 (Outbox Flush)** must complete before **Phase 2 (Master Data Refresh)** begins. This mathematically prevents older server state from overwriting uncommitted field sales work.
4. **Local Stock Protection & Soft Warning**: Placing an order immediately decrements local van stock. If an order exceeds remaining local stock, a soft warning alerts the officer while still allowing business execution if needed.
5. **Periodic & Event-Driven Triggers**: 15-minute background periodic timer when online, plus immediate triggers on network reconnection (`connectivity_plus`), app lifecycle resume, and manual "Sync Now".

---

## 3. Database Schema (SQLite Version 2 Migration)

Upgrades `offline_store.db` from version 1 to 2 with WAL mode (`PRAGMA journal_mode = WAL`) enabled.

### 3.1 Relational Tables

#### `local_distributors`
Stores distributors assigned to the sales officer:
* `id` INTEGER PRIMARY KEY
* `name` TEXT NOT NULL
* `phone` TEXT
* `mobile` TEXT
* `warehouse_id` INTEGER
* `warehouse_name` TEXT
* `updated_at` TEXT NOT NULL

#### `local_routes`
Stores routes assigned to the officer:
* `id` INTEGER PRIMARY KEY
* `name` TEXT NOT NULL
* `distributor_id` INTEGER NOT NULL
* `outlet_count` INTEGER DEFAULT 0
* `sequence` INTEGER DEFAULT 10
* `updated_at` TEXT NOT NULL
* *Index:* `idx_local_routes_distributor` on `distributor_id`

#### `local_outlets`
Stores outlets under the officer's routes:
* `id` INTEGER PRIMARY KEY
* `route_id` INTEGER NOT NULL
* `name` TEXT NOT NULL
* `code` TEXT
* `owner_name` TEXT
* `phone` TEXT
* `street` TEXT
* `latitude` REAL
* `longitude` REAL
* `radius_meters` REAL DEFAULT 150.0
* `sequence` INTEGER DEFAULT 10
* `updated_at` TEXT NOT NULL
* *Indexes:* `idx_local_outlets_route` on `route_id`, `idx_local_outlets_coords` on `(latitude, longitude)`

#### `local_products_stock`
Stores master product catalog with van stock:
* `id` INTEGER PRIMARY KEY
* `name` TEXT NOT NULL
* `default_code` TEXT
* `barcode` TEXT
* `unit_price` REAL NOT NULL DEFAULT 0.0
* `uom_name` TEXT
* `category_id` INTEGER
* `category_name` TEXT
* `van_stock` REAL NOT NULL DEFAULT 0.0
* `updated_at` TEXT NOT NULL
* *Indexes:* `idx_local_products_code` on `default_code`, `idx_local_products_category` on `category_name`

#### `local_distributor_stocks`
Stores warehouse stock per distributor for secondary sales order booking:
* `distributor_id` INTEGER NOT NULL
* `product_id` INTEGER NOT NULL
* `stock_qty` REAL NOT NULL DEFAULT 0.0
* `nearest_expiry` TEXT
* `updated_at` TEXT NOT NULL
* *Primary Key:* `(distributor_id, product_id)`
* *Indexes:* `idx_dist_stock_dist` on `distributor_id`, `idx_dist_stock_prod` on `product_id`

#### `local_vans`
Stores virtual van loading locations linked to the officer:
* `id` INTEGER PRIMARY KEY
* `name` TEXT NOT NULL
* `employee_id` INTEGER NOT NULL
* `distributor_id` INTEGER
* `updated_at` TEXT NOT NULL

#### `local_reference_metadata`
Stores operational reference collections (visit reasons, scrap reasons, return reasons):
* `key` TEXT PRIMARY KEY
* `group_name` TEXT NOT NULL
* `data_json` TEXT NOT NULL
* `updated_at` TEXT NOT NULL

---

## 4. Two-Phase Synchronization Pipeline (`MasterDataSyncService`)

### Phase 1: Outbound Outbox Replay (FIFO)
1. Query `outbox_operations` where `status = 'PENDING'` ordered by `id ASC`.
2. Replay each operation via `ApiService.executeRawPost`.
3. If an operation succeeds: mark `COMPLETED` and purge.
4. If an operation fails with a fatal business conflict (e.g., customer partner inactive): mark `QUARANTINED` to unblock queue.
5. If an operation fails with a transient network error (socket drop, 502/503/504, timeout): leave `PENDING` and abort sync pass.
6. Verify that `pendingCount == 0` before proceeding to Phase 2.

### Phase 2: Inbound Master Data Hydration
Only executed when Phase 1 finishes with zero pending items:
1. `GET /api/v1/contacts` (customer_type = 'distributor') $\rightarrow$ populate `local_distributors`.
2. `GET /api/v1/ss/routes` (employee_id) $\rightarrow$ populate `local_routes`.
3. For each route: `GET /api/v1/ss/routes/<route_id>` $\rightarrow$ populate `local_outlets`.
4. `GET /api/v1/virtual-locations` (employee_id) $\rightarrow$ populate `local_vans`.
5. For each assigned distributor: `GET /api/v1/products` (`sale_type = 'secondary'`, `partner_id = distributor.id`) $\rightarrow$ populate `local_products_stock` (master catalog details and van stock) and `local_distributor_stocks` (`distributor_id`, `product_id`, `stock_qty`, `nearest_expiry`).
6. `GET /api/v1/visits/reasons` $\rightarrow$ populate `local_reference_metadata`.
7. All inbound entities are written in a single atomic SQLite transaction (`db.transaction()`). If network interrupts midway, transaction rolls back cleanly without partial corruption.

---

## 5. Local-First Event-Driven Mutations

### 5.1 Secondary Sale Order Placement
```dart
// 1. Check local stock (both van stock and distributor stock)
final product = await dbHelper.getLocalProduct(productId);
final distStock = await dbHelper.getDistributorStock(distributorId, productId);

// Evaluates available stock based on fulfillment mode (van spot delivery or distributor warehouse dispatch)
final availableStock = isVanDelivery ? product.vanStock : distStock;
if (availableStock < requestedQty) {
  final proceed = await showSoftWarningDialog(
    'Requested qty exceeds remaining stock ($availableStock). Proceed anyway?',
  );
  if (!proceed) return;
}

// 2. Atomic local mutation & outbox enqueue
await dbHelper.executeTransaction((txn) async {
  await txn.rawUpdate(
    'UPDATE local_products_stock SET van_stock = MAX(0, van_stock - ?) WHERE id = ?',
    [requestedQty, productId],
  );
  await txn.insert('outbox_operations', orderOutboxMap);
});

// 3. UI updates immediately in 0ms
// 4. Trigger sync in background if online
```

### 5.2 Visit Check-In / Check-Out
* Generates `client_visit_uuid` (UUIDv4).
* Immediately updates active visit state in `local_reference_metadata`.
* Enqueues `/api/v1/visits/create` in outbox.
* All orders created during this session link `parent_uuid = client_visit_uuid`.

---

## 6. Sync Scheduling & Background Timers

1. **Login Trigger**: Runs complete hydration after `AuthProvider.login()` completes.
2. **Periodic Timer**: Fires every 15 minutes when device has active network.
3. **Connectivity Jitter**: When `connectivity_plus` detects transition from offline to online, applies a 3–18 second randomized jitter before Phase 1 to prevent Odoo server thundering herd.
4. **Lifecycle Trigger**: Fires on `AppLifecycleState.resumed`.
5. **Manual Trigger**: "Sync Now" button on the Offline & Outbox screen.

---

## 7. Verification & Testing Strategy

1. **Schema Migration Tests**: Ensure existing SQLite installations migrate to v2 without data loss.
2. **Pipeline Sequencing Tests**: Verify Phase 2 is blocked until Phase 1 outbox is completely flushed.
3. **Local Stock Decrement Tests**: Verify `van_stock` drops immediately in SQLite on order placement and soft warning triggers when exceeded.
4. **Resilience & Transaction Rollback Tests**: Verify network drop during Phase 2 rolls back SQLite transaction without data corruption.
5. **Static Analysis**: 0 errors on `flutter analyze`.
