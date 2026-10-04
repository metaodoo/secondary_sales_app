# System Architecture & Technical Data Flows
## GDFL Secondary Sales & Sales Force Automation (SFA) Mobile Application

* **Document Version:** 1.0.0
* **Target System:** `secondary_sales` (Flutter Client) & Odoo 18 ERP Backend
* **Date:** October 4, 2026
* **Location:** `/home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/02_SYSTEM_ARCHITECTURE_AND_DATA_FLOWS.md`

---

## 1. System Topology & Component Map

The application follows a distributed client-server architecture where a Flutter mobile client communicates with an Odoo 18 Enterprise ERP server via a dedicated, secure REST API gateway.

```mermaid
graph TD
    subgraph "Mobile Client Device (Flutter)"
        UI_ISO["UI Isolate\n(Main Thread / Widgets / Providers)"]
        BG_ISO["Background Service Isolate\n(flutter_background_service)"]
        SQLITE_DB[("Local SQLite Buffer\nlocations.db")]
        SHARED_PREF[("SharedPreferences\n(Tokens, Metadata, Policy)")]
        
        UI_ISO <--> SHARED_PREF
        BG_ISO <--> SHARED_PREF
        BG_ISO -->|Insert GNSS Fixes| SQLITE_DB
        UI_ISO -->|Inspect Buffered Count| SQLITE_DB
    end

    subgraph "Security & API Gateway Layer"
        AUTH_MOD["meta_api_user\n(JWT Sessions, Token Rotation, ss.module, RBAC)"]
        GATEWAY_MOD["meta_ss_rest_api\n(API Router, Policy Middleware, Error Boundaries)"]
        UI_ISO -->|Bearer JWT Requests| GATEWAY_MOD
        BG_ISO -->|Batch Flush GPS POST| GATEWAY_MOD
        GATEWAY_MOD --> AUTH_MOD
    end

    subgraph "Odoo 18 Backend Core (gdfl Suite)"
        SALES["meta_ss_sales\n(Orders, Invoices, Delivery Validation)"]
        TRANSFER["meta_ss_transfer\n(Van Stock, Virtual Transfers, Scraps)"]
        ROUTES["meta_ss_route_management\n(Beat Routes, Scheduled Outlets, Visits)"]
        CONTACTS["meta_ss_contact\n(Outlet Master, Scrap/Stock Locations)"]
        HR_MOD["meta_ss_attendance / expense / leave_request"]
        TRACKING["meta_ss_location_tracking\n(GPS Checkpoints, Route History)"]
        FCM_MOD["meta_firebase_push_notification\n(FCM Devices & Message Queue)"]
        BARIKOI_MOD["Barikoi Suite (5 Modules)\n(Address Autocomplete & Geocoding)"]
    end

    GATEWAY_MOD --> SALES & TRANSFER & ROUTES & CONTACTS & HR_MOD & TRACKING
    FCM_MOD -->|FCM Push Notification| UI_ISO
    BARIKOI_MOD -.->|Maps & Geocoding| UI_ISO
```

---

## 2. Multi-Isolate Execution Model (Flutter)

To guarantee that field GPS tracking continues uninterrupted even if the user minimizes the app, locks the device, or clears the app from the recent tasks list, the application utilizes a dual Dart isolate architecture:

### 2.1 The UI Isolate (Main Thread)
* **Responsibilities:** Renders the Material 3 UI widgets, handles user touches, manages feature state via Provider, executes map rendering, and performs user-initiated business transactions (Order booking, Check-in, Expense upload).
* **Network Management:** Uses a singleton `ApiService.instance` configured with interceptors for token refresh and error handling.

### 2.2 The Background Service Isolate
* **Responsibilities:** Hosted inside an Android Foreground Service (`flutter_background_service`) bound to a sticky ongoing notification (Notification ID 913: *"Attendance active"*).
* **Isolation Constraints:** The background isolate runs on a separate memory heap and cannot access the UI's Provider or `ApiService` in-memory state.
* **Coordination Protocol:**
  1. Shares persistent credentials with the UI isolate via `SharedPreferences`.
  2. Directly accesses the local SQLite database (`locations.db`) via `LocationDbHelper.instance`.
  3. Periodically flushes buffered GPS fixes to Odoo independently.
  4. Emits cross-isolate events (`service.invoke('autoCheckOutVisits', {...})`) to notify the UI isolate if a sales rep has drifted away from an outlet.

```mermaid
sequenceDiagram
    autonumber
    participant UI as UI Isolate (Main App)
    participant Prefs as SharedPreferences
    participant BG as Background Isolate (Foreground Service)
    participant SQLite as SQLite Buffer (locations.db)
    participant Odoo as Odoo 18 REST Gateway

    UI->>Odoo: POST /api/v1/hr/attendance/action (Clock-In)
    Odoo-->>UI: 200 OK (Attendance Recorded)
    UI->>Prefs: Write tracking config (active=true, sync_interval=300)
    UI->>BG: LocationTrackingService.startService()
    
    loop Every Tracking Cadence (e.g. 5 min / distance > 50m)
        BG->>BG: Geolocator.getCurrentPosition()
        BG->>SQLite: LocationDbHelper.insertLocation(lat, lng, UTC_time, is_mock)
    end

    loop Every Sync Interval (e.g. 1 hour or forced on Clock-Out)
        BG->>SQLite: LocationDbHelper.getBufferedLocations()
        SQLite-->>BG: Return List of unsynced points (IDs 1..N)
        BG->>Prefs: Read JWT Access Token & Server URL
        BG->>Odoo: POST /api/v1/employee/location/sync (Batch Coordinates)
        Odoo-->>BG: 200 OK (Batch Committed to Postgres)
        BG->>SQLite: LocationDbHelper.deleteUpToId(N)
    end

    UI->>Odoo: POST /api/v1/hr/attendance/action (Clock-Out)
    UI->>BG: Force immediate final flush & terminate service
```

---

## 3. Detailed Technical Data Flows

### 3.1 Authentication & Session Bootstrap Flow
```mermaid
sequenceDiagram
    autonumber
    actor User as Field Officer
    participant App as Mobile App
    participant AuthAPI as /api/v1/auth/login
    participant BootAPI as /api/v1/auth/bootstrap-session
    participant SyncAPI as /api/v1/access/catalog/sync

    User->>App: Submits Username & Password
    App->>AuthAPI: POST credentials
    AuthAPI-->>App: 200 OK (JWT Access Token, Refresh Token, User Metadata)
    App->>BootAPI: POST /bootstrap-session (Bearer Token)
    BootAPI-->>App: Return Employee Profile, Active Shift Status, Module Entitlements
    App->>SyncAPI: POST Screen & Action Catalog (Version Check)
    SyncAPI-->>App: Catalog Verified & Active RBAC Policies Returned
    App->>User: Renders Dynamic Dashboard
```

### 3.2 Outlet Visit & Geofence Verification Flow
```mermaid
sequenceDiagram
    autonumber
    actor TSO as Territory Sales Officer
    participant App as Mobile App UI
    participant Geo as Device GPS Hardware
    participant API as /api/v1/visits/create

    TSO->>App: Taps "Check-In" on target Outlet
    App->>Geo: Requests high-accuracy current location
    Geo-->>App: Returns Latitude, Longitude, Accuracy
    App->>App: Calculates Haversine distance to Outlet GPS
    
    alt Distance <= Configured Radius (e.g. 50 meters)
        App->>API: POST /api/v1/visits/create (outlet_id, lat, lng, in_geofence=true)
        API-->>App: 200 OK (Visit Record Created)
        App->>TSO: Starts Active Visit Timer & Opens Order Creation
    else Distance > Configured Radius (Out of Geofence)
        App->>TSO: Redirects to Out-of-Geofence Justification Screen
        TSO->>App: Selects Reason (e.g. Shop Relocated) & Takes Camera Photo
        App->>API: POST /api/v1/visits/create (outlet_id, lat, lng, in_geofence=false, reason, photo_base64)
        API-->>App: 200 OK (Visit Created with Audit Flag)
        App->>TSO: Opens Order Creation
    end
```

### 3.3 Secondary Sales Order Booking Flow
```mermaid
sequenceDiagram
    autonumber
    actor TSO as Territory Sales Officer
    participant App as Mobile App UI
    participant LotSelector as SearchableLotSelector
    participant API as /api/v1/sales/orders/create
    participant Odoo as Odoo 18 ERP Backend

    TSO->>App: Adds Products to Cart (Quantity, UoM)
    TSO->>LotSelector: Selects batch/lot number
    
    opt If Lot is Expired or Near-Expiry
        LotSelector->>App: Triggers ExpiredLotsConfirmationDialog
        TSO->>App: Explicitly confirms or cancels
    end

    opt If Quantity > Warehouse Stock
        App->>TSO: Displays StockExcessDialog warning
    end

    TSO->>App: Taps "Submit Order"
    App->>API: POST /api/v1/sales/orders/create (outlet_id, lines: [{product_id, qty, uom, lot_id, price}])
    API->>Odoo: Executes with @mobile_api_error_boundary
    Odoo->>Odoo: Creates draft sale.order, verifies credit terms, calculates promotions
    Odoo-->>API: sale.order ID & confirmation payload
    API-->>App: 200 OK (Order Confirmed)
    App->>TSO: Displays Order Summary & Thermal Print Option
```

---

## 4. Odoo 18 Backend Micro-Module Architecture

The backend architecture comprises 19 custom modules located in `/home/abrar/odoo/odoo_18/custom/gdfl`, each responsible for a distinct architectural domain:

| Domain | Modules | Core Responsibility |
|---|---|---|
| **Security & Auth** | `meta_api_user` | Mobile user sessions, JWT creation and refresh, `ss.module` management, and UI resource catalog. |
| **API Gateway** | `meta_ss_rest_api` | Central HTTP gateway, `@mobile_api_error_boundary`, RBAC policy evaluation (`require_ui_access`), and shared catalog endpoints. |
| **Sales & Distribution** | `meta_ss_sales` | Secondary sale order creation, auto-invoicing, delivery pickings, and sales target tracking. |
| **Van & Inventory Transfers** | `meta_ss_transfer` | Van mobile warehouse transfers, load-in/load-out pickings, returns, and scrap inventory movements. |
| **Route & Beat Management** | `meta_ss_route_management` | Beat route planning, scheduled outlet lines, store visit tracking, and visit performance analytics. |
| **Outlets & Master Data** | `meta_ss_contact` | Extends `res.partner` for retail outlets, auto-generates stock and scrap locations, and links distributors. |
| **Field HR & Time Tracking** | `meta_ss_attendance`, `meta_ss_expense`, `meta_ss_leave_request`, `meta_ss_employee` | Geofenced clock-in/out, paperless expense claims with receipt uploads, leave management, and employee directories. |
| **Location & Supervision** | `meta_ss_location_tracking` | High-volume GPS coordinate ingestion, batch sync endpoints, and subordinate route playback for supervisors. |
| **Push Notifications** | `meta_firebase_push_notification`, `meta_ss_mobile_notifications` | Firebase device token management, background push notifications, and in-app notification center inbox. |
| **Geospatial & Mapping** | `meta_barikoi_base`, `meta_barikoi`, `meta_barikoi_address_autocomplete`, `meta_barikoi_geolocalize`, `meta_barikoi_partner_map` | Barikoi Bangladesh maps, geocoding, reverse-geocoding, address autocomplete, and coordinate validation. |
| **Audit & Attribution** | `meta_ss_chatter_attribution` | Attributes automated system actions executed over the API back to the actual acting mobile sales representative in Odoo chatter feeds. |
