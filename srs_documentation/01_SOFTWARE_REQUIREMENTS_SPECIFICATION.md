# Software Requirements Specification (SRS)
## GDFL Secondary Sales & Sales Force Automation (SFA) Mobile Application

* **Document Version:** 1.0.0
* **Target System:** `secondary_sales` (Flutter Mobile Application)
* **Backend:** Odoo 18 Enterprise/Community ERP (`gdfl` custom backend suite)
* **Target Platforms:** Android (Primary Deployment), iOS, Linux/Desktop (Testing/Diagnostic)
* **Date of Documentation:** October 4, 2026
* **Location:** `/home/niaj/Documents/GDFL/secondary_sales_app/`

---

## 1. Introduction & Executive Summary

### 1.1 Purpose
This Software Requirements Specification (SRS) provides an exhaustive and comprehensive specification of the **Secondary Sales & SFA Mobile Application** developed for **Gazi Dairy & Food Ltd. (GDFL)**. The system transitions field operations from manual paper-based processes and disparate communication channels into a centralized, real-time, geofenced, and offline-resilient sales automation platform integrated directly with Odoo 18 ERP.

### 1.2 Scope of the System
The mobile application manages the end-to-end field sales lifecycle:
* **Territory & Route Planning:** Beat schedule management, retail outlet assignment, and automated sequence ordering.
* **Smart Outlet Proximity:** Client-side distance calculation (Haversine formula) and sorting of stores without server load.
* **Geofenced Visit Management:** Mandatory GPS geofence validation for store check-ins, out-of-geofence justification workflows, photographic evidence capture, and automated checkout upon route drift.
* **Secondary Sales Order Booking:** On-site retail order capture, batch/lot selection, near-expiry and expired batch alerts, stock availability checks, trade promotion calculation, and auto-invoicing.
* **Modern Trade (MT) Operations:** Dedicated workflows for hypermarkets and supermarkets including shelf inventory auditing, planogram compliance, PO booking, and replacement returns.
* **Van Sales & Mobile Inventory Transfers:** Virtual stock location management, van load-in/load-out pickings, and mobile stock tracking.
* **Returns & Scrap Processing:** Intake of damaged, spoiled, or expired goods, automated scrap warehouse routing, and customer credit adjustment.
* **Field HR & Attendance:** Geofenced clock-in/out at assigned distributor warehouses, facial photo verification, and automated background tracking initiation.
* **High-Resilience Background GPS Tracking:** Dedicated foreground service isolate recording GPS coordinates into a local SQLite database (`locations.db`), distance threshold filtering to eliminate battery drain, and periodic batch flushing.
* **Field Expenses & Leave Requests:** Paperless receipt capture, expense submissions, leave entitlement queries, and multi-tier approval tracking.
* **Field Team Supervision ("My Team"):** Supervisor map dashboard with live field rep tracking and historical breadcrumb route inspection.
* **Notifications & Notice Center:** Hybrid push messaging via Firebase Cloud Messaging (FCM) and Odoo In-App Notification Center with deep-linking directly into transaction records.

---

## 2. User Personas & Access Roles

| Role Identifier | Role Name | Primary Responsibilities & Functional Scope |
|---|---|---|
| **TSO / SR** | Territory Sales Officer / Sales Representative | Beat route execution, outlet check-ins, secondary sales order booking, customer returns, scrap submissions, attendance, and expense filing. |
| **MT_REP** | Modern Trade Merchandiser | Supermarket/hypermarket store audits, shelf stock recording, planogram verification, PO intake, and MT-specific returns. |
| **VAN_REP** | Van Sales & Delivery Representative | Mobile warehouse management, van stock loading/unloading, customer delivery validation, cash collection, and damage logging. |
| **ASM / SUP** | Area Sales Manager / Field Supervisor | Team tracking, subordinate route breadcrumb trail inspection, field attendance monitoring, expense approval, and leave authorization. |
| **SYS_ADMIN** | System Administrator | Role assignment, UI catalog synchronization, territory master data setup, and mobile configuration policies. |

---

## 3. Technology Stack & Core Architecture

* **Framework:** Flutter SDK `^3.12.0` (Dart 3.12+), configured with Material 3 theming.
* **State Management:** Provider `^6.1.5+1` with feature-scoped ChangeNotifier providers.
* **Local Storage & Database:**
  * `sqflite: ^2.4.0` (ACID-compliant SQLite database for crash-proof GPS buffering).
  * `shared_preferences: ^2.5.5` (Session tokens, user metadata, and persistent feature flags).
* **Background Isolate & Services:**
  * `flutter_background_service: ^5.0.10` running in an independent Dart isolate with an Android persistent foreground notification (ID 913).
  * `permission_handler: ^11.3.1` (Runtime permissions for Background Location, Camera, Notifications).
* **Geospatial & Mapping:**
  * `geolocator: ^14.0.2` (Hardware GNSS/GPS coordinate capture).
  * `flutter_map: ^8.3.1` & `latlong2: ^0.10.1` (Interactive OpenStreetMap tile renderer).
  * `maplibre_gl: ^0.26.2` (Barikoi Bangladesh Map vector tile rendering).
* **Push Notifications:**
  * `firebase_core: ^3.1.0` and `firebase_messaging: ^15.0.0` for FCM push delivery.
* **Hardware & Document Interfacing:**
  * `image_picker: ^1.2.3` (Camera capture and compression for receipts and visit photos).
  * `printing: ^5.13.0` (Thermal Bluetooth and network printing for invoices and receipts).
  * `file_picker: ^8.1.2` (Document and certificate attachments for leave and HR).
* **Backend ERP:** Odoo 18 (Community & Enterprise) hosting 19 custom `gdfl` micro-addons communicating via RESTful Bearer JWT endpoints.

---

## 4. Security & Role-Based Access Control (RBAC)

### 4.1 Authentication & Token Lifecycle
1. **Login & Session Issuance:** Reps authenticate using mobile credentials via `POST /api/v1/auth/login`. The server returns an Access Token (Bearer JWT), a Refresh Token, expiration timestamps, user details, and assigned company ID.
2. **Token Refresh Mutex:** When an access token expires, `AuthService.refreshSession()` automatically intercepts the 401 response and requests a fresh token using `POST /api/v1/auth/refresh`. Concurrent requests queue up to prevent duplicate refresh calls.
3. **Session Bootstrap:** On application launch, `POST /api/v1/auth/bootstrap-session` validates token validity, refreshes employee master data, updates active attendance status, and synchronizes access gates.

### 4.2 Dynamic UI Access Control Engine
* **Resource Catalog (`mobile.ui.resource`):** The app registers all UI screens and executable actions in `menu_catalog.dart` and `access_keys.py`. On startup or version upgrade, it synchronizes this catalog with Odoo via `POST /api/v1/access/catalog/sync`.
* **Module-Based Gating (`ss.module`):** Roles are assigned high-level modules:
  * `secondary_sales`
  * `primary_sales`
  * `modern_trade`
  * `hr_attendance`
  * `expense_management`
* **Widget-Level Enforcement:**
  * `PermissionGate`: Wraps UI controls, buttons, and Floating Action Buttons (FABs). If a user's role lacks the permission key, the button is either hidden or rendered in a disabled state.
  * Methods `auth.canView(screenKey)` and `auth.canDo(actionKey)`.

---

## 5. Detailed Functional Specifications

### 5.1 App Shell & Navigation
* **Components:** `AppShell`, `AppDrawer`, `MenuCatalog`.
* **Behavior:**
  * Implements a bottom navigation bar for core tabs: **Dashboard**, **Orders**, **Outlets**, **Settings**.
  * The drawer dynamically displays menu sections according to the active module (`modern_trade` vs `secondary_sales`) and the user's role permissions.

### 5.2 Interactive Dashboard & KPI Analytics
* **Components:** `DashboardScreen`, `DashboardProvider`, `DashboardCards`.
* **Features:**
  * **MTD Sales Performance:** Shows Month-To-Date target vs achievement with visual progress bars and percentage metrics.
  * **Today's Visit Tracker:** Visual breakdown of total assigned outlets, visited outlets, and remaining pending stores.
  * **Quick Action Launcher:** Fast-access grid for "New Order", "Check In", "Deliveries", "Van Load", and "Attendance".
  * **Live Attendance Banner:** Displays active check-in duration or prompts for morning clock-in.

### 5.3 Beat Route & Schedule Management
* **Components:** `RouteListScreen`, `RouteDetailScreen`, `CreateRouteScreen`, `RouteProvider`.
* **Features:**
  * Displays assigned weekly routes with day-of-week recurrence.
  * Lists scheduled outlets in sequence with route completion status indicators.
  * Allows creating custom beat routes and dynamically inserting emergency or unscheduled outlets.

### 5.4 Outlet Directory & Smart Proximity Sorting
* **Components:** `OutletsListScreen`, `EditOutletScreen`, `ProximityHelper`.
* **Features:**
  * **Client-Side Distance Calculation:** Calculates real-time Haversine distance between current device GPS coordinates and all stored outlet coordinates.
  * **Proximity Sorting:** Sorts outlets from nearest to farthest instantly without making backend network calls, saving bandwidth and battery.
  * **Outlet Onboarding:** Form for creating new retail outlets with name, owner contact, tax identification, and one-tap GPS coordinate geotagging.
  * **Address Autocomplete:** Uses Barikoi Geolocation API to auto-fill street, upazila, and district.

### 5.5 Store Visit Execution & Geofence Verification
* **Components:** `OutletSelectionScreen`, `CheckInScreen`, `VisitDetailsScreen`, `OutOfGeoFenceScreen`.
* **Features:**
  * **Geofence Radius Check:** Validates whether the representative is within the configured geofence radius (e.g. 50–100m) of the target store.
  * **Out-of-Geofence Justification Flow:** If outside the radius, check-in is blocked unless the rep submits a mandatory justification reason (e.g. "Shop Relocated", "GPS Signal Weak", "Owner Met at Depot") accompanied by a live camera photo.
  * **Active Visit Timer:** Displays a real-time counter measuring total time spent inside the store.
  * **Non-Sales Visit Logging:** Allows logging visits where no order was placed, capturing reason codes (e.g., "Overstocked", "Shop Closed", "Owner Unavailable").
  * **Automated Drift Checkout:** Automatically flags or checks out visits if the rep moves beyond the geofence perimeter during background location sync.

### 5.6 Secondary Sales Order Booking
* **Components:** `OrderCreationScreen`, `ProductSelectionScreen`, `OrderDetailScreen`, `SearchableLotSelector`.
* **Features:**
  * **Product Catalog:** Real-time search, category navigation, multi-UoM conversion (e.g., Carton to Piece), and tiered wholesale pricing.
  * **Batch / Lot Traceability:** Dropdown selector to choose specific stock lots/batches for traceability.
  * **Expired Lots Protection:** Displays `ExpiredLotsConfirmationDialog` alerting the rep if a selected batch is nearing expiry or has passed its expiration date.
  * **Stock Excess Dialog:** Prevents or flags orders where requested quantities exceed distributor or van warehouse inventory.
  * **Order Calculations:** Real-time computation of gross total, trade promotions/discounts, applicable VAT, and net amount payable.
  * **Draft Order Replay:** Automatically creates a draft `sale.order` in Odoo linked to the retail outlet partner and distributor.

### 5.7 Primary Sales Orders (Distributor Replenishment)
* **Components:** `CreatePrimarySaleScreen`, `PrimarySaleProvider`.
* **Features:**
  * Enables field officers to place replenishment orders on behalf of distributors directly to the GDFL manufacturing plant.
  * Displays distributor credit limits, outstanding ledger balances, and payment terms.

### 5.8 Delivery Validation & Dispatch Reconciliation
* **Components:** `DeliveriesListScreen`, `ValidateDeliveryScreen`.
* **Features:**
  * Lists scheduled delivery orders pending customer receipt.
  * Line-by-line item verification allowing reps to record delivered quantities vs transit damages.
  * Digital signature or OTP verification confirming delivery, triggering automated stock picking validation in Odoo.

### 5.9 Modern Trade (MT) Specialized Workflow
* **Components:** `MtOutletsScreen`, `MtStockAuditListScreen`, `MtStockAuditDetailScreen`, `MtSecOrdersListScreen`, `MtReturnsListScreen`.
* **Features:**
  * **Store Audits:** Detailed shelf inventory audits capturing on-shelf stock, back-store stock, facing counts, and competitor retail pricing.
  * **Planogram Compliance:** Photographic capture of shelf displays for merchandising review.
  * **Purchase Order (PO) Processing:** Direct entry of chain supermarket purchase order numbers against secondary sale lines.
  * **MT Returns:** Special return requests for supermarket chain spoilage and damages.

### 5.10 Van Loading & Mobile Warehouse Transfers
* **Components:** `VanOperationsListScreen`, `VirtualTransferListScreen`, `CreateVirtualTransferScreen`.
* **Features:**
  * Treats sales vans as virtual inventory locations (`stock.location`).
  * **Van Load-In:** Requests stock transfer from central distributor warehouse into the delivery van before starting the route.
  * **Van Load-Out:** Reconciles end-of-day unsold stock returning to the warehouse.
  * **Inter-Van Stock Balancing:** Transfers inventory between mobile sales vans in the field.

### 5.11 Customer Returns & Scrap Management
* **Components:** `ReturnsListScreen`, `CreateReturnScreen`, `ScrapsListScreen`, `CreateScrapScreen`.
* **Features:**
  * Categorizes returns into restockable merchandise vs scrap goods.
  * Records mandatory return reasons (e.g., Leakage, Package Damage, Expired, Wrong Dispatch).
  * Direct scrap generation routes spoiled dairy products into the outlet's designated scrap location in Odoo.

### 5.12 Field HR Attendance
* **Components:** `AttendanceScreen`, `AttendanceProvider`.
* **Features:**
  * Geofenced clock-in / clock-out validating physical presence at the assigned distributor depot.
  * Camera selfie capture verifying rep identity.
  * Administrative bypass support for authorized exceptions.
  * Starting attendance initiates the background tracking service; clocking out triggers a final location buffer flush and terminates the service.

### 5.13 High-Resilience Background GPS Location Tracking & SQLite Buffer
* **Components:** `LocationTrackingService`, `LocationDbHelper`, `LocationBufferScreen`.
* **Features:**
  * **Isolated Background Service:** Powered by `flutter_background_service` in a standalone Dart isolate. Runs as an Android Foreground Service with an ongoing notification (`Attendance active`, ID 913), guaranteeing execution when the app is backgrounded, the screen is locked, or the app is swiped away from recent apps.
  * **Intelligent Distance & Cadence Filtering:** Captures GNSS coordinates at regular intervals (default 5 minutes), filtered by a distance threshold to avoid recording redundant data while stationary.
  * **Crash-Safe SQLite Storage:** Coordinates are immediately inserted into the local SQLite database (`locations.db`, table `buffered_locations`) containing `latitude`, `longitude`, `recorded_at` (UTC string), and `is_mock`.
  * **Batch Synchronization:** The service periodically bundles buffered coordinates and flushes them to Odoo via `POST /api/v1/employee/location/sync`. Upon receiving HTTP 200 OK, rows up to `maxId` are deleted atomically.
  * **Diagnostic Screen:** An in-app diagnostic view (`LocationBufferScreen`) allows field staff and IT engineers to inspect buffered point counts, check battery optimization state, monitor last flush time, and trigger manual flushes.

### 5.14 Field Expense Management
* **Components:** `ExpenseDashboardScreen`, `ExpenseCreateSheet`, `ExpenseDetailsSheet`.
* **Features:**
  * Category-based expense logging (Fuel, Conveyance, Meals, Accommodation, Miscellaneous).
  * Direct camera photo capture of paper receipts with on-device compression.
  * Submission directly to Odoo `hr.expense.sheet` workflow.
  * Real-time expense status tracking (Draft, Submitted, Approved, Reimbursed).

### 5.15 Leave Requests & Approvals
* **Components:** `LeaveDashboardScreen`, `LeaveRequestSheet`.
* **Features:**
  * Real-time query of leave entitlements (Casual, Sick, Annual).
  * Multi-day leave application with auto-calculation of working days.
  * Attachment of medical certificates or supporting documents via file picker.
  * Status updates for pending, approved, and rejected applications.

### 5.16 Field Team Supervision ("My Team" Module)
* **Components:** `MyTeamScreen`, `SubordinateCheckpointsScreen`, `SubordinateBarikoiCheckpointsScreen`.
* **Features:**
  * Real-time monitoring dashboard for supervisors displaying subordinates' active shifts, battery levels, current beat route, and latest GPS coordinates.
  * **Interactive Route Playback:** Renders chronological breadcrumb paths of reps on OpenStreetMap (`flutter_map`) or Barikoi Vector Maps (`maplibre_gl`).
  * Checkpoint inspector detailing timestamp, speed, and location address for each recorded point.

### 5.17 In-App Notifications & Deep-Linking
* **Components:** `NotificationsScreen`, `NotificationDetailScreen`, `NoticeDetailScreen`, `PushNotificationService`, `NotificationRouter`.
* **Features:**
  * Registers FCM device tokens with Odoo backend via `POST /api/v1/device/register`.
  * In-app notification center inbox tracking read/unread status and badge counts.
  * Deep-linking handler that navigates users directly to the referenced document (e.g. Sale Order, Delivery Note, Leave Request) upon tapping a notification.

---

## 6. Offline Architecture & Resilience Roadmap

### 6.1 Current Operational Offline State
1. **GPS Route Compliance:** 100% offline resilient. Coordinates are stored in local SQLite (`locations.db`) and flushed automatically whenever internet connectivity becomes available.
2. **Session Persistence:** Auth tokens, user profiles, and permission gates are cached in `SharedPreferences`, enabling the background service and app to boot and operate without immediate internet connectivity.
3. **Outlet Proximity Calculation:** Offline Haversine distance engine calculates distances using locally cached outlet coordinates.

### 6.2 Full Offline Write Queue Specification (`OFFLINE_PLAN.md` & `SYNC_PLAN.md`)
* **Guiding Principle:** "Online-first foundation, client-side buffer layer". Odoo remains the single source of truth; zero changes to Odoo JSON-RPC endpoints.
* **Sync Triggers:**
  1. `AppLifecycleState.resumed` (App returning to foreground).
  2. `connectivity_plus` network connection restoration stream.
  3. User-initiated manual "Sync Now" button.
* **Replay Pipeline:** Offline write actions (Orders, Visits, Scraps) stored in a local SQLite queue and replayed against Odoo sequentially with conflict resolution and user error reporting.

---

## 7. Non-Functional Requirements & Performance SLAs

1. **Battery Life SLA:** Background location logging must consume less than 3% device battery per 8-hour shift through smart distance-threshold throttling.
2. **Resilience & Fault Tolerance:** The app must survive process kills, device reboots, and network dropouts without data loss or corruption of un-synced GPS coordinates.
3. **Data Integrity & Rollbacks:** All backend transactions must execute within `@mobile_api_error_boundary` decorators to ensure automatic rollback on failure.
4. **Security:** Zero plaintext credentials stored on device; all communications use TLS 1.3 encryption with rotating Bearer JWT tokens.
