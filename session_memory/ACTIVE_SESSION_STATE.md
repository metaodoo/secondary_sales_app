# Active Session State & Context Continuation
## GDFL Secondary Sales & Sales Force Automation (SFA) System

* **File Location:** `/home/niaj/Documents/GDFL/secondary_sales_app/session_memory/ACTIVE_SESSION_STATE.md`
* **Last Updated:** 2026-10-04T13:20:00+06:00
* **Conversation ID:** `747d9712-4afb-429e-b2aa-dd4332f95108`
* **Purpose:** Serves as the authoritative, persistent session memory to protect against system automated context compaction, guaranteeing zero loss of architectural decisions, business rules, and technical roadmaps.

---

## 1. System Identity & Environment

* **Target Application:** `secondary_sales` (Flutter Mobile Application)
* **Client Codebase:** [`/home/niaj/Documents/GDFL/secondary_sales_app/`](file:///home/niaj/Documents/GDFL/secondary_sales_app/)
* **Backend ERP:** Odoo 18 Enterprise/Community (`gdfl` custom suite, 19 modules at `/home/abrar/odoo/odoo_18/custom/gdfl/`)
* **Primary Target OS:** Android (Mobile Field Deployment), iOS, Linux/Desktop
* **Client Tech Stack:**
  * Flutter SDK `^3.12.0` (Dart 3.12+), Material 3
  * Provider `^6.1.5+1` for state management
  * `sqflite: ^2.4.0` for local crash-proof SQLite storage (`locations.db`)
  * `flutter_background_service: ^5.0.10` for persistent Android foreground tracking (ID 913)
  * `geolocator: ^14.0.2` for GNSS capture
  * `flutter_map: ^8.3.1` (OpenStreetMap) & `maplibre_gl: ^0.26.2` (Barikoi Maps Bangladesh)
  * `firebase_messaging: ^15.0.0` for FCM push delivery

---

## 2. Business Logic & Validation Rules Matrix

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       BUSINESS LOGIC & POLICIES                                        │
├──────────────────────────────┬─────────────────────────────────────────────────────────────────────────┤
│ Domain                       │ Rules & Constraints Enforced                                            │
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 1. Auth & Session Lifecycle  │ • Rotating Bearer JWT + Refresh Token with centralized mutex lock.      │
│                              │ • Module-level access: General Trade (`secondary_sales`) vs             │
│                              │   Modern Trade (`modern_trade`), HR & Attendance, Expenses.              │
│                              │ • RBAC: Dynamic catalog synced to Odoo `mobile.ui.resource`;           │
│                              │   `PermissionGate` evaluates module grants minus exception lists.       │
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 2. Beat Routes & Visits      │ • Weekly scheduled routes with ordered outlet sequences (`route.line`). │
│                              │ • Geofence Check: 50–100m Haversine radius validation.                  │
│                              │ • Out-of-Geofence: Mandatory reason code + camera photo justification.  │
│                              │ • Non-Sales Visits: Mandatory reason if no order placed.                │
│                              │ • Auto-Drift Checkout: Cross-isolate event if rep moves beyond distance │
│                              │   threshold while a visit is active.                                    │
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 3. Secondary Order Booking   │ • Order booked on behalf of outlet's assigned distributor partner.      │
│                              │ • Lot/Batch Selection with mandatory traceability.                      │
│                              │ • Expired Batch Protection: Explicit confirmation modal blocks          │
│                              │   accidental sale of expired dairy inventory.                           │
│                              │ • Stock Excess Dialog: Alerts if order exceeds on-hand warehouse stock. │
│                              │ • Automated calculation of tiered pricing, UoM conversions, VAT.        │
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 4. Van Sales & Mobile Stock  │ • Vans modeled as mobile virtual `stock.location`s.                     │
│                              │ • Load-In: Depot to Van stock transfer before route start.              │
│                              │ • Load-Out: EOD unsold stock reconciliation & return.                   │
│                              │ • Inter-van stock balancing between field reps.                         │
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 5. Returns & Scrap           │ • Return Classification: Restockable vs Scrap.                          │
│                              │ • Damaged dairy routed to outlet scrap locations.                       │
│                              │ • Reason codes: Leakage, breakage, expiry, wrong SKU.                   │
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 6. HR Attendance & GPS Engine│ • Clock-in: Geofenced at distributor depot + selfie photo proof.        │
│                              │ • Service Coupling: Attendance starts foreground tracking isolate       │
│                              │   (Notification ID 913); checkout forces final flush and terminates.    │
│                              │ • Adaptive Throttling: Distance thresholding suppresses stationary      │
│                              │   fixes (<3% battery drain per 8h shift).                               │
│                              │ • Local SQLite Buffer (`locations.db`): Crash-safe inserts; batch       │
│                              │   flush to Odoo; atomic purge up to maxId.                              │
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 7. Modern Trade (MT) Flow    │ • Supermarket Audits: Facing counts, shelf stock, back-store stock,     │
│                              │   competitor price tracking.                                            │
│                              │ • Chain PO Mapping: Direct PO number binding to orders.                 │
│                              │ • Planogram photo verification.                                         │
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 8. Supervisory ("My Team")   │ • Live subordinate monitoring: Battery, GPS, shift status.              │
│                              │ • Route Playback: Chronological breadcrumb trails over OpenStreetMap    │
│                              │   (`flutter_map`) and Barikoi Vector Tiles.                             │
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 9. Offline Transaction Queue │ • Dual-UUID backend resolution: `outlet.visit.uuid` & `sale.order.uuid`. │
│    & Causal Dependencies     │ • Composite batch endpoint `POST /api/v1/sync/batch` (`cr.savepoint`).  │
│                              │ • Graceful degradation: credit/stock limits degrade to Draft/Held state.│
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 10. Non-Transient Remediation│ • Dead-letter quarantine: Failed rows never block subsequent items.      │
│     (Sync Issues Drawer)     │ • Interactive mobile wizard: Reassign outlet, request reactivation, or  │
│                              │   edit malformed parameters (e.g. missing lots) and resubmit.           │
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 11. Multi-User & Concurrency │ • 3-Tier Sync: Tier 1 (FCM silent push invalidation), Tier 2            │
│     (bus.bus + Tombstones)   │   (Foreground WebSocket `bus.bus` for shared locations), Tier 3        │
│                              │   (Delta sync with `sync.tombstone` tracking soft/hard deletions).      │
│                              │ • Shared warehouse stock contention: second order backorders gracefully.│
├──────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
│ 12. Modular Resync Center    │ • In-app Sync & Storage Center: Granular resync per domain (Outlets,    │
│     (Full & Domain Sync)     │   Products, Stock, Invoices, Routes) + Force Full Reload without wiping  │
│                              │   outbox queue.                                                         │
└──────────────────────────────┴─────────────────────────────────────────────────────────────────────────┘
```


---

## 3. Architecture & Data Flow Reference

### 3.1 Dual Dart Isolate Execution
* **UI Isolate:** Handles UI rendering, user actions, Provider state management, and real-time Haversine distance sorting ([`ProximityHelper`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/core/util/proximity_helper.dart)).
* **Background Isolate:** Hosted in an Android Foreground Service (`flutter_background_service`) with notification ID 913. It runs independently of UI state, writes GPS coordinates directly to SQLite `locations.db`, and flushes batches to `POST /api/v1/employee/location/sync`.

### 3.2 Odoo Backend Micro-Modules (19 Total)
Located at `/home/abrar/odoo/odoo_18/custom/gdfl/`:
1. `meta_api_user` (JWT Auth, sessions, `ss.module`, RBAC catalog)
2. `meta_ss_rest_api` (API router, `@mobile_api_error_boundary`, policy middleware)
3. `meta_ss_sales` (Orders, auto-invoicing, deliveries)
4. `meta_ss_transfer` (Van stock, virtual transfers, returns, scraps)
5. `meta_ss_route_management` (Routes, lines, store visits)
6. `meta_ss_contact` (Outlet master data, scrap/stock virtual locations)
7. `meta_ss_location_tracking` (GPS coordinate sync, route checkpoints)
8. `meta_ss_attendance` (Geofenced attendance check-in/out)
9. `meta_ss_expense` (Field expense submission & receipts)
10. `meta_ss_leave_request` (Leave requests & balances)
11. `meta_ss_employee` (Sales employee directory)
12. `meta_ss_mobile_notifications` (In-app notification center)
13. `meta_firebase_push_notification` (FCM device registration & message dispatching)
14. `meta_ss_chatter_attribution` (Logs API edits back to acting mobile user)
15. `meta_barikoi_base` (Barikoi REST API wrapper)
16. `meta_barikoi` (Umbrella Barikoi module)
17. `meta_barikoi_address_autocomplete` (Address autocompletion)
18. `meta_barikoi_geolocalize` (Reverse geocoding & coordinate locking)
19. `meta_barikoi_partner_map` (Embedded MapLibre partner maps)

---

## 4. Key Documentation Links

All generated SRS, architectural specifications, and offline blueprints are located in:
* Master Index: [`/home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/README.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/README.md)
* Full SRS: [`/home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/01_SOFTWARE_REQUIREMENTS_SPECIFICATION.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/01_SOFTWARE_REQUIREMENTS_SPECIFICATION.md)
* Architecture & Flows: [`/home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/02_SYSTEM_ARCHITECTURE_AND_DATA_FLOWS.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/02_SYSTEM_ARCHITECTURE_AND_DATA_FLOWS.md)
* Offline & Sync Engine: [`/home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/03_OFFLINE_AND_SYNC_ARCHITECTURE.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/03_OFFLINE_AND_SYNC_ARCHITECTURE.md)
* API & Data Models Matrix: [`/home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/04_API_ENDPOINTS_AND_DATA_MODELS_MATRIX.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/04_API_ENDPOINTS_AND_DATA_MODELS_MATRIX.md)
* 🚀 **Master Offline Architecture Plan (Hardened Blueprint):** [`/home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/05_MASTER_OFFLINE_ARCHITECTURE_PLAN.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/05_MASTER_OFFLINE_ARCHITECTURE_PLAN.md)
* 📋 **Real-World FMCG Operational SOPs (15y Sales GM Perspective):** [`/home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/06_REAL_WORLD_BANGLADESH_FMCG_OPERATIONAL_SOPS.md`](file:///home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/06_REAL_WORLD_BANGLADESH_FMCG_OPERATIONAL_SOPS.md)

---

## 5. Decision & Progress Tracker

| Milestone / Decision | Status | Description |
|---|---|---|
| Historical Mobile App Conversation Retrieved | ✅ Completed | Found conversation `56794f6c-06d6-4e07-915b-51c857e1219e` referencing the SFA offline app. |
| Full Codebase Inspection | ✅ Completed | Audited 18 feature modules, 21 REST API endpoints, 26 data models, and services. |
| Comprehensive SRS Generation | ✅ Completed | Documented all functional workflows, business rules, geofencing, and SLAs. |
| Offline & Sync Architecture Documented | ✅ Completed | Synthesized production SQLite `locations.db` + future write queue replay engine. |
| Session Memory Persisted | ✅ Completed | Saved in `session_memory/ACTIVE_SESSION_STATE.md` to survive automated context compaction. |
| POS & Timesheet Offline Deep Study | ✅ Completed | Audited Odoo 18/19 POS IndexedDB/UUID/sync_from_ui pattern and timesheet timer services. |
| Multi-Perspective Architectural Critique | ✅ Completed | Engaged `odoo_solution_critic` subagent; identified and resolved causal patching, 401 traps, and SQLite locks. |
| Master Offline Architecture Plan Authored | ✅ Completed | Formulated foolproof blueprint (`05_MASTER_OFFLINE_ARCHITECTURE_PLAN.md`) with dual-UUID resolution & graceful degradation. |
| Real-World FMCG SOPs Formalized | ✅ Completed | Documented 6 core field SOPs (`06_REAL_WORLD_BANGLADESH_FMCG_OPERATIONAL_SOPS.md`) based on Bangladesh sales GM psychology. |
| Zero-UI Disruption Under-the-Hood Interceptor Designed | ✅ Completed | Mapped transparent 4h offline architecture inside `ApiService._post` preventing ANR & 429 rate limits. |
| Persistent Android Media Storage Engine | ✅ Completed | Implemented `MediaStorageService` in `lib/core/services/media_storage_service.dart`. Saved photos to persistent `app_flutter/gdfl_media/<category>/` directory across 6 call sites (Scraps, Returns, Visits, Outlets, Attendance, Expenses) to protect against OS cache clearing during 4h offline operations. |
| SQLite WAL Outbox & Master Cache Engine | ✅ Completed | Implemented `OfflineDatabaseHelper` (`offline_store.db`) with `PRAGMA journal_mode = WAL;` and 5000ms busy timeout. Created `outbox_operations` queue table (UUIDv4, causal parent_uuid, retry count, quarantined state) and `cached_master_data` store. |
| Background Sync Worker & Rate Limiter | ✅ Completed | Implemented `OfflineSyncEngine` with `connectivity_plus`, 3–18s randomized reconnect jitter (DDoS thundering herd protection), leaky-bucket throttling (2 req/s), FIFO causal replay, and `WidgetsBindingObserver` lifecycle triggers. |
| Zero-UI Disruption Transparent Interceptor | ✅ Completed | Integrated transparent fallback into `ApiService._post` & `executeRawPost`. Fast-path immediate write buffering and read cache lookup when offline (0ms latency, zero UI stalls). Auto-caching master data upon online read success. |
| Android Build & Test Pipeline Verification | ✅ Completed | Fixed Gradle Kotlin DSL (`kotlin-android` plugin, `jvmTarget.set(JVM_17)`), upgraded NDK to `28.2.13676358`, and resolved Dart SDK constraint to `^3.11.0`. `flutter build apk --debug` succeeded (`build/app/outputs/flutter-apk/app-debug.apk` generated). All unit/widget tests passing (13/13). |
| End-to-End Automated QA Pipeline Test Suite | ✅ Completed | Authored `test/e2e_offline_pipeline_test.dart` with 7 comprehensive field scenarios: master data caching, offline check-in, causal order booking with parent linking, damage returns, FIFO outbox flush, non-transient error quarantine, and transient network glitch backoff. |
| Adversarial Field Stress Testing & Hardening | ✅ Completed | Simulated naive sales officer sabotage attempts (multi-tap rage clicks, sudden app kill/crash mid-sync, empty line-item submissions, corrupt 0-byte camera captures, and orphaned visit-orders). Implemented outbox idempotency debouncing, startup stale operation recovery, empty order validation, active visit persistence, and media size guards. 23/23 tests passing with 100% success. |

---


## 6. How This Memory Is Maintained
Whenever automated compaction occurs or new instructions/modifications are introduced, this file serves as the canonical rehydration baseline. All updates made during development should be recorded directly back into this file.

