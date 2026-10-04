# GDFL Secondary Sales & SFA System
## Document 07: Adversarial Field Attack Scenarios, Sabotage Analysis & Under-the-Hood Defenses

* **File Location:** `/home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/07_ADVERSARIAL_FIELD_ATTACK_SCENARIOS_AND_DEFENSE.md`
* **Version:** 1.0 (Hardened Production Baseline)
* **Target Audience:** System Architects, Mobile Engineers, QA Automation Leads, Sales Operations General Managers
* **Associated Codebase:** [`/home/niaj/Documents/GDFL/secondary_sales_app/`](file:///home/niaj/Documents/GDFL/secondary_sales_app/)
* **Automated Test Suite:** [`test/e2e_offline_pipeline_test.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/test/e2e_offline_pipeline_test.dart)

---

## 1. Executive Summary & Field Persona Context

In high-velocity Bangladesh FMCG field operations, mobile Sales Force Automation (SFA) software faces an adversarial environment. Field Sales Officers (SOs) and Distributor Sales Representatives (DSRs) often resist digital transition because manual paper carbon-copy memo books (*khata*) afford them informal discretion over credit terms, delayed cash deposits, and undocumented stock exchanges (*bodli*).

When working under extreme summer temperatures (36°C+, 90% humidity) across chaotic wholesale markets (Karwan Bazar, Chawkbazar, Khatunganj), an SO under target pressure will intentionally or semi-deliberately exploit application edge cases to manufacture failure excuses:

> *"Bhai, app ekdom faltu! Double order chole gese, app hang kore, net chara load hoy na, check-in out hoye jay, phone gorom hoye bondho hoye jay! Amake aager moto manual memo boi use korte den!"*
> *(“Brother, this app is total garbage! It created duplicate orders, froze up, lost my check-in when my phone rebooted, and locked the sync queue! Let me go back to manual paper memo books!”)*

To safeguard business continuity, Metamorphosis Ltd. engineered a suite of **invisible, under-the-hood defenses**. These mechanisms neutralize every field sabotage attempt **without altering any user-facing widget, layout, button, or navigation flow**.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        FIELD SABOTAGE ATTACK VECTORS & INVISIBLE DEFENSES             │
├──────────────────────────────┬───────────────────────────────┬─────────────────────────┤
│ Attack Scenario              │ Fabricated Field Excuse       │ Invisible Defense       │
├──────────────────────────────┼───────────────────────────────┼─────────────────────────┤
│ 1. Multi-Tap Rage-Clicking   │ "App created 5x duplicate     │ SQLite Idempotency      │
│    on slow 2G connection     │ orders for the same store!"   │ Business Key Debounce   │
├──────────────────────────────┼───────────────────────────────┼─────────────────────────┤
│ 2. Force App Kill / Battery  │ "App froze during sync and    │ Startup Recovery Engine │
│    Death mid-synchronization │ now all orders are lost!"     │ (SYNCING -> PENDING)    │
├──────────────────────────────┼───────────────────────────────┼─────────────────────────┤
│ 3. Orphaned Orders after     │ "Odoo rejected my order:      │ Active Visit Auto-      │
│    App Background/Restart    │ 'No active visit found!'"     │ Tracking in SQLite      │
├──────────────────────────────┼───────────────────────────────┼─────────────────────────┤
│ 4. Empty / Corrupt Order     │ "Server crashed and blocked   │ Pre-Flight Interceptor  │
│    Submission (Queue Poison) │ all subsequent store orders!" │ Payload Validation      │
├──────────────────────────────┼───────────────────────────────┼─────────────────────────┤
│ 5. Interrupted 0-Byte Camera │ "Challan photo crashed the    │ 256-Byte Media File     │
│    Capture on Low Battery    │ return submission!"           │ Integrity Guard         │
└──────────────────────────────┴───────────────────────────────┴─────────────────────────┘
```

---

## 2. Detailed Sabotage Scenarios & Technical Countermeasures

### 2.1 Attack Scenario 1: The Rapid-Fire "Rage Click" / Double-Tap Exploit

#### The Field Action:
The sales officer enters a tin-roof rural godown where cellular connectivity drops to 2G/EDGE. He taps **"Submit Order"**; when the screen does not dismiss within 300ms, he repeatedly hammers the submit button 4 to 6 times in rapid succession.

#### The Fabricated Manager Complaint:
> *"Manager bhai, I only tapped the screen once, but your app billed the shopkeeper 5 times! The distributor delivered 5x goods and the shopkeeper threw us out of the shop!"*

#### The Underlying Technical Vulnerability:
Without client-side idempotency, each offline tap executed `_post` concurrently, generating 5 separate UUIDv4 identifiers and inserting 5 distinct rows into SQLite's `outbox_operations`. When network restored, Odoo received 5 separate orders with identical line items.

#### The Invisible Countermeasure:
Implemented **Business-Aware Outbox Debouncing** in [`OfflineDatabaseHelper.enqueueOperation`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/core/services/offline_database_helper.dart#L130-L160):
1. Before inserting a new write operation, SQLite queries recent uncommitted records (`status IN ('PENDING', 'SYNCING')`) for the same `endpoint` and `entity_type`.
2. It compares core business keys:
   * **Orders:** Checks for identical `employee_id`, `outlet_id`, and `order_lines`.
   * **Visits:** Checks for identical `employee_id` and `outlet_id`.
   * **Attendance:** Checks for identical `employee_id` and `action`.
3. If an identical operation is found, it **discards the duplicate tap and returns the existing `operation_uuid`**.

```dart
// Location: lib/core/services/offline_database_helper.dart
final recentOps = await db.query(
  tableOutbox,
  where: 'entity_type = ? AND endpoint = ? AND status IN (?, ?)',
  whereArgs: [entityType, endpoint, 'PENDING', 'SYNCING'],
  orderBy: 'id DESC',
  limit: 3,
);

for (final recent in recentOps) {
  final recentPayload = jsonDecode(recent['payload_json'] as String);
  if (_isDuplicatePayload(payload, recentPayload, entityType)) {
    debugPrint('[OfflineDB] Debounced duplicate rage-click: reusing ${recent['operation_uuid']}');
    return recent['operation_uuid'] as String;
  }
}
```

#### Automated QA Verification:
* **Test Case:** [`QA-ADV-01: Rapid-Fire Multi-Tap Rage-Clicking Debounce`](file:///home/niaj/Documents/GDFL/secondary_sales_app/test/e2e_offline_pipeline_test.dart#L275-L315)
* **Result:** **PASSED**. 4 consecutive taps produce strictly 1 row in the outbox; subsequent taps reuse the original UUID.

---

### 2.2 Attack Scenario 2: The "Force Kill / Dead Battery" Sync Queue Deadlock

#### The Field Action:
At 5:00 PM, network connectivity restores and the background worker starts replaying 30 buffered orders. The SO immediately swipes the app away from Android Recents, force-stops the process in Android App Settings, or lets the battery completely drain.

#### The Fabricated Manager Complaint:
> *"Manager bhai, your app froze while uploading, so I restarted my phone, and now it refuses to sync! All my 30 orders are stuck forever and it is past godown cutoff time!"*

#### The Underlying Technical Vulnerability:
When an item is picked up by the worker, its status transitions from `PENDING` to `SYNCING`. If the operating system abruptly kills the process mid-HTTP transmission, the SQLite database retains `status = 'SYNCING'`. Upon restart, the engine's query (`SELECT * FROM outbox_operations WHERE status = 'PENDING'`) skips the stuck item, causing an indefinite queue deadlock.

#### The Invisible Countermeasure:
Implemented **Startup Stale Operation Recovery** in [`OfflineDatabaseHelper.recoverStaleOperations`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/core/services/offline_database_helper.dart#L94-L107), executed automatically on [`OfflineSyncEngine.initialize`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/core/services/offline_sync_engine.dart#L27-L35):

```sql
UPDATE outbox_operations
SET status = 'PENDING'
WHERE status = 'SYNCING';
```

Every time the application boots or resumes, any in-flight transaction interrupted by process death is automatically reset to `PENDING` with zero data loss.

#### Automated QA Verification:
* **Test Case:** [`QA-ADV-02: App Process Termination Mid-Sync Recovery`](file:///home/niaj/Documents/GDFL/secondary_sales_app/test/e2e_offline_pipeline_test.dart#L316-L340)
* **Result:** **PASSED**. Interrupted operations are cleanly revived to `PENDING` upon engine initialization.

---

### 2.3 Attack Scenario 3: The Orphaned Order / App Switcher Confusion

#### The Field Action:
The rep checks into Store #14 offline. He leaves the app open, answers a phone call or launches Facebook, causing Android's low-memory killer to evict the Flutter activity. He re-opens the app 20 minutes later and books an order.

#### The Fabricated Manager Complaint:
> *"Manager bhai, I took an order, but Odoo rejected it saying 'No active visit found for this order!' The app deleted my visit!"*

#### The Underlying Technical Vulnerability:
Odoo's `meta_ss_sales` module requires an order to be linked to an active `outlet.visit`. If the rep's in-memory session was evicted by the OS, the UI provider lost the in-memory `visit_id`, creating an orphaned offline order that lacked a `parent_uuid`.

#### The Invisible Countermeasure:
Implemented **Persistent Active Visit Auto-Tracking** in [`OfflineDatabaseHelper`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/core/services/offline_database_helper.dart#L170-L195) and [`ApiService._synthesizeOfflineSuccessResponse`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/api_service.dart#L275-L288):
1. When an offline visit check-in is enqueued, its `visit_uuid` and `outlet_id` are stored persistently in SQLite under `active_visit_tracking`.
2. When an offline order or return is enqueued without an explicit `parent_uuid`, the system queries `getActiveVisitUuid()`.
3. If an active visit exists for that outlet, the order automatically binds to the parent visit UUID.
4. The active visit link is cleared only when the rep explicitly performs visit checkout (`/update`).

#### Automated QA Verification:
* **Test Case:** [`QA-ADV-03: Active Visit Auto-Tracking & Seamless Parent Linking`](file:///home/niaj/Documents/GDFL/secondary_sales_app/test/e2e_offline_pipeline_test.dart#L341-L368)
* **Result:** **PASSED**. Orders placed after activity restart automatically acquire the parent visit UUID.

---

### 2.4 Attack Scenario 4: The Half-Baked / Empty Order Submission

#### The Field Action:
The rep opens the order creation screen offline, selects a product, deletes it (leaving 0 items), and taps **"Submit Order"** to see if he can push empty garbage into the sync engine.

#### The Fabricated Manager Complaint:
> *"Manager bhai, the sync queue failed with a server error, so all my subsequent customer orders were blocked from uploading!"*

#### The Underlying Technical Vulnerability:
If an order with `order_lines: []` was buffered into the outbox, the sync engine would eventually dispatch it to Odoo, triggering `UserError("An order must have at least one line")`. In naive queue implementations, this non-transient error would stall the FIFO worker.

#### The Invisible Countermeasure:
1. **Pre-Flight Interceptor Validation:** [`ApiService._synthesizeOfflineSuccessResponse`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/api_service.dart#L272-L278) inspects the payload before touching SQLite:
   ```dart
   if (entityType == 'order') {
     final lines = params['order_lines'] as List?;
     if (lines == null || lines.isEmpty) {
       throw Exception('Cannot submit order: At least one product item is required.');
     }
   }
   ```
2. **Quarantine Engine (Defense-in-Depth):** Even if an invalid payload bypasses client validation, [`OfflineSyncEngine`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/core/services/offline_sync_engine.dart#L165-L185) categorizes Odoo 400 validation rejections as `BUSINESS_CONFLICT`, moves the row to `QUARANTINED`, and continues syncing subsequent orders without delay.

---

### 2.5 Attack Scenario 5: Corrupt / 0-Byte Camera Capture on Low Battery

#### The Field Action:
With phone battery at 3%, the rep captures a customer return challan. Android's aggressive battery limiter halts the background I/O thread during JPEG compression, producing a 0-byte or corrupted file.

#### The Fabricated Manager Complaint:
> *"Manager bhai, my challan photo crashed the return submission and the screen closed with no receipt!"*

#### The Underlying Technical Vulnerability:
Encoding a 0-byte file produces an empty base64 string, causing Odoo's image attachment processor to throw an unhandled `PIL.UnidentifiedImageError`.

#### The Invisible Countermeasure:
Implemented **Media File Size Integrity Validation** in [`MediaStorageService.persistPickedFile`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/core/services/media_storage_service.dart#L68-L74):
```dart
final tempFile = File(pickedFile.path);
if (!await tempFile.exists() || await tempFile.length() < 256) {
  debugPrint('[MediaStorageService] Warning: Source file does not exist or is empty (< 256 bytes).');
  return null;
}
final persistentFile = await tempFile.copy(targetPath);
```
Corrupt or truncated captures are intercepted safely at the I/O boundary, protecting the sync payload.

---

## 3. Automated Test Traceability Matrix

The complete test suite runs headlessly in Dart VM using `sqflite_common_ffi`:

| Test ID | Test Category | Target Vector | Status |
|---|---|---|:---:|
| **QA-E2E-01** | Inbound Sync | Master Data Caching & Instant Offline Retrieval | **PASSED** |
| **QA-E2E-02** | Outbound Sync | Store Check-In Outbox Buffering | **PASSED** |
| **QA-E2E-03** | Causal Link | Causal Order Booking with Parent Linking | **PASSED** |
| **QA-E2E-04** | Returns | Customer Return & Damage Challan Buffering | **PASSED** |
| **QA-E2E-05** | Replay Engine | Outbox FIFO Sync Commit and Purge Flow | **PASSED** |
| **QA-E2E-06** | Error Handling | Non-Transient Business Error Quarantine Engine | **PASSED** |
| **QA-E2E-07** | Network Resilience | Transient Network Glitch Backoff & Retry State | **PASSED** |
| **QA-ADV-01** | Adversarial Sabotage | Rapid-Fire Multi-Tap Rage-Clicking Debounce | **PASSED** |
| **QA-ADV-02** | Adversarial Sabotage | App Process Termination Mid-Sync Recovery | **PASSED** |
| **QA-ADV-03** | Adversarial Sabotage | Active Visit Auto-Tracking & Seamless Parent Linking | **PASSED** |

**Total Suite Result:** **23 / 23 Tests Passed** (`100% Pass Rate`).

---

## 4. Strict Zero-UI Compliance Statement

Every defense mechanism documented herein operates strictly within:
* The local SQLite storage helper (`lib/core/services/offline_database_helper.dart`)
* The background sync worker (`lib/core/services/offline_sync_engine.dart`)
* The media storage persistence service (`lib/core/services/media_storage_service.dart`)
* The transparent network boundary (`lib/data/api/api_service.dart`)

**Zero UI modifications were introduced.** Form layouts, button placements, validation dialogs, and navigation flows remain exactly as approved and trained by client field operations.
