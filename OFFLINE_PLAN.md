# Offline Support — Implementation Plan

## Decision: Online First

Build the full online app first. Offline support is a layer on top of a working app,
not a foundation.

**Why:**

- You cannot design a good sync queue until you know exactly what writes exist and
  what their failure modes are.
- The API contract is still evolving (auth not enforced yet, secondary sale creation
  still TODO). Adding a local DB now means migrating the schema every time an API
  response shape changes.
- Drift schema migrations are painful when the underlying data model is still in flux.

---

## What to Keep in Mind While Building Online

These cost nothing to do now and save significant time when the offline layer is added:

1. **Fix the shared `ApiService` instance (REVIEW.md #3) early.** Every screen that
   gets wired up before this is fixed makes the retrofit harder.

2. **Keep all API calls inside `ApiService` methods.** No raw `http` calls in
   providers or screens. This makes wrapping with a repository layer straightforward
   later.

3. **Build `toMap()` alongside `fromMap()` on every model.** `toMap()` is the only
   thing needed for local DB writes. Building it now alongside `fromMap()` costs
   nothing and avoids a large retroactive pass later.

---

## When to Start Offline Work

Start after:
- Full online app is feature-complete and stable
- API contract is locked (auth enforced, secondary sale creation implemented)
- All major model shapes are settled

---

## Recommended Stack

| Package | Purpose |
|---------|---------|
| `drift` | Type-safe SQLite ORM with migrations and reactive streams |
| `connectivity_plus` | Detect online/offline state |
| `path_provider` | Locate DB file on device |

**Why Drift over raw `sqflite`:** Compile-time type-safe queries, automatic migration
support, and stream-based reactivity that works naturally with Provider. For a
relational dataset (distributors → routes → outlets → orders), SQL is the right fit
over Hive/Isar.

---

## Target Architecture

**Current:**
```
Screen → Provider → ApiService → Odoo
```

**Offline-capable:**
```
Screen → Provider → Repository → ApiService  (online)
                              ↘ LocalDatabase (offline / cache)
                    SyncQueue → ApiService    (on reconnect)
```

The `Repository` layer makes the decision: if online, call the API and cache the
result; if offline, serve from the local DB. Writes made offline go into a
`SyncQueue` table and are replayed when connectivity is restored.

---

## Local Database Schema

### Read Cache Tables

```
distributors
  id, name, phone, mobile, email, street, city, active

outlets
  id, name, phone, mobile, email, street, city, active, route_id

routes
  id, name, code, active, distributor_id

route_outlets
  route_id, outlet_id, sequence, expected_visit_time

products
  id, name, default_code, price, tracking, uom_id, uom_name

employees
  id, name, work_email, mobile_phone, distributor_id

sale_orders
  id, name, state, sale_type, partner_id, employee_id, date_order, amount_total

sale_order_lines
  id, order_id, product_id, qty, price_unit, discount

virtual_transfers
  id, name, state, scheduled_date, source_location_id, dest_location_id
```

### Sync Queue Table (Write Buffer)

```
sync_queue
  id              INTEGER PRIMARY KEY
  operation       TEXT     -- 'create_order', 'validate_transfer', 'cancel_order', etc.
  endpoint        TEXT     -- '/api/v1/sale-orders/create'
  payload         TEXT     -- JSON blob
  created_at      INTEGER  -- Unix timestamp
  status          TEXT     -- 'pending', 'syncing', 'done', 'failed'
  retry_count     INTEGER
  error_message   TEXT
```

---

## Repository Pattern (per domain)

```dart
class OrderRepository {
  final ApiService _api;
  final LocalDatabase _db;
  final ConnectivityService _connectivity;

  // Reads: cache-first when offline
  Future<List<PrimaryOrder>> getOrders({...}) async {
    if (await _connectivity.isOnline) {
      final orders = await _api.getRecentOrders(...);
      await _db.upsertOrders(orders);
      return orders;
    }
    return _db.getOrders(...);
  }

  // Writes: queue when offline
  Future<void> createOrder(Map<String, dynamic> payload) async {
    if (await _connectivity.isOnline) {
      await _api.createPrimarySalesOrder(...);
    } else {
      await _db.enqueueSyncOp(
        operation: 'create_order',
        endpoint: '/api/v1/sale-orders/create',
        payload: jsonEncode(payload),
      );
    }
  }
}
```

---

## SyncService (runs on connectivity restore)

```dart
class SyncService {
  Future<void> syncPendingOperations() async {
    final pending = await _db.getPendingSyncOps();
    for (final op in pending) {
      try {
        await _db.markSyncing(op.id);
        await _api.post(op.endpoint, jsonDecode(op.payload));
        await _db.markDone(op.id);
      } catch (e) {
        await _db.markFailed(op.id, e.toString());
      }
    }
  }
}
```

---

## What Works Offline vs. What Does Not

| Feature | Offline | Notes |
|---------|---------|-------|
| View distributors / outlets / routes | Yes | Served from cache |
| View product catalog | Yes | Served from cache |
| View existing sale orders | Yes | Served from cache |
| Create a primary sale order | Yes (queued) | Replayed on reconnect |
| Cancel / confirm an order | Yes (queued) | Replayed on reconnect |
| Create van loading transfer | Yes (queued) | Lot validation is online-only |
| Validate a delivery | Partial | Stock quantities may be stale |
| Create distributor / employee | Yes (queued) | |
| View virtual transfers | Yes | Served from cache |

---

## Biggest Risk: Stale Stock Data

Van loading transfers and delivery validation depend on real-time stock quantities.
If a sales officer queues a transfer offline and someone else has already moved that
stock, the sync will fail with a stock validation error.

The sync queue must handle this:
- A `retry_count` cap (e.g. max 3 attempts)
- A `failed` status surfaced to the user with the server error message
- A UI screen showing pending and failed sync items
- Per-item retry and discard actions

This is the hardest part of offline support for an inventory app and needs careful
UX design before implementation.

---

## Implementation Order (when the time comes)

1. Set up Drift schema with core read-cache tables
2. Ensure shared `ApiService` instance is in place (prerequisite)
3. Add `ConnectivityService` wrapper around `connectivity_plus`
4. Implement `Repository` layer for read operations (cache-first for lists)
5. Add `sync_queue` table and `SyncService`
6. Wrap write operations (create order, create transfer) to enqueue when offline
7. Add UI indicator for pending sync items
8. Handle sync failures with user-visible error and retry/discard options
