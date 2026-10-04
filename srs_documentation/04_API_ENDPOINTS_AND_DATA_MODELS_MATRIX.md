# API Endpoints & Data Models Matrix
## GDFL Secondary Sales & Sales Force Automation (SFA) Mobile Application

* **Document Version:** 1.0.0
* **Target System:** `secondary_sales` (Flutter Client) & Odoo 18 Backend
* **Date:** October 4, 2026
* **Location:** `/home/niaj/Documents/GDFL/secondary_sales_app/srs_documentation/04_API_ENDPOINTS_AND_DATA_MODELS_MATRIX.md`

---

## 1. REST API Endpoints Directory

All endpoints use JSON payloads and require Bearer JWT authentication in the `Authorization` HTTP header (except `/auth/login`). Responses are wrapped in a standard JSON envelope:
```json
{
  "success": true,
  "api_version": "1.0",
  "message": "Operation completed successfully.",
  "data": { ... }
}
```

### 1.1 Authentication & Security (`meta_api_user`)
| Endpoint | Method | Source File | Description |
|---|---|---|---|
| `/api/v1/auth/login` | `POST` | [`auth_service.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/auth_service.dart) | Authenticates user credentials; returns JWT access token, refresh token, user details. |
| `/api/v1/auth/bootstrap-session` | `POST` | [`auth_service.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/auth_service.dart) | Re-validates session on app launch; returns employee metadata, attendance status, module config. |
| `/api/v1/auth/refresh` | `POST` | [`auth_service.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/auth_service.dart) | Issues fresh access token using a valid refresh token. |
| `/api/v1/auth/logout` | `POST` | [`auth_service.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/auth_service.dart) | Revokes active mobile session and invalidates refresh token. |

### 1.2 Access Control & Catalog (`meta_ss_rest_api`)
| Endpoint | Method | Source File | Description |
|---|---|---|---|
| `/api/v1/access/permissions` | `POST` | [`access_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/access_api.dart) | Retrieves client-side permission gates (`enforced` and `granted` keys). |
| `/api/v1/access/catalog/sync` | `POST` | [`access_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/access_api.dart) | Syncs Flutter app UI screen & button keys to Odoo `mobile.ui.resource`. |

### 1.3 Dashboard & Executive Metrics (`meta_ss_rest_api`)
| Endpoint | Method | Source File | Description |
|---|---|---|---|
| `/api/v1/dashboard/summary` | `POST` | [`dashboard_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/dashboard_api.dart) | Returns MTD sales targets vs achievements, daily visit counts, and order totals. |

### 1.4 Route Management & Store Visits (`meta_ss_route_management`)
| Endpoint | Method | Source File | Description |
|---|---|---|---|
| `/api/v1/ss/routes` | `POST` | [`routes_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/routes_api.dart) | Lists all beat routes assigned to the sales officer. |
| `/api/v1/ss/routes/create` | `POST` | [`routes_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/routes_api.dart) | Creates a new beat route with scheduled weekdays and assigned outlets. |
| `/api/v1/ss/routes/<id>` | `POST` | [`routes_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/routes_api.dart) | Fetches detailed outlet sequence and route lines for a specific route. |
| `/api/v1/visits` | `POST` | [`visits_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/visits_api.dart) | Lists visit history across outlets. |
| `/api/v1/visits/create` | `POST` | [`visits_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/visits_api.dart) | Records a store check-in, geofence status, visit reasons, and photo evidence. |
| `/api/v1/visits/today` | `POST` | [`visits_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/visits_api.dart) | Fetches status of today's scheduled vs visited outlets. |

### 1.5 Sales & Deliveries (`meta_ss_sales`)
| Endpoint | Method | Source File | Description |
|---|---|---|---|
| `/api/v1/sales/orders` | `POST` | [`sales_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/sales_api.dart) | Lists historical secondary sales orders. |
| `/api/v1/sales/orders/create` | `POST` | [`sales_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/sales_api.dart) | Books a secondary sale order with batch/lot numbers and promotional pricing. |
| `/api/v1/sales/orders/<id>` | `POST` | [`sales_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/sales_api.dart) | Retrieves line items and delivery status of a specific order. |
| `/api/v1/deliveries` | `POST` | [`deliveries_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/deliveries_api.dart) | Lists pending and validated customer delivery pickings. |
| `/api/v1/deliveries/validate` | `POST` | [`deliveries_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/deliveries_api.dart) | Reconciles delivered vs damaged goods and validates stock picking. |

### 1.6 Modern Trade Operations (`meta_ss_sales` / `meta_ss_route_management`)
| Endpoint | Method | Source File | Description |
|---|---|---|---|
| `/api/v1/mt/outlets` | `POST` | [`modern_trade_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/modern_trade_api.dart) | Lists modern trade chain outlets assigned to the merchandiser. |
| `/api/v1/mt/stock-audit/list` | `POST` | [`modern_trade_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/modern_trade_api.dart) | Lists historical store shelf inventory audits. |
| `/api/v1/mt/stock-audit/create` | `POST` | [`modern_trade_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/modern_trade_api.dart) | Submits on-shelf, back-store stock counts, facings, and competitor prices. |
| `/api/v1/mt/orders/create` | `POST` | [`modern_trade_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/modern_trade_api.dart) | Submits MT secondary orders mapped to supermarket chain PO numbers. |
| `/api/v1/mt/returns/create` | `POST` | [`modern_trade_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/modern_trade_api.dart) | Submits MT return requests for damaged/expired supermarket inventory. |

### 1.7 Van Stock Transfers, Returns & Scraps (`meta_ss_transfer`)
| Endpoint | Method | Source File | Description |
|---|---|---|---|
| `/api/v1/virtual-transfers` | `POST` | [`transfers_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/transfers_api.dart) | Lists van loading/unloading and inter-van stock transfers. |
| `/api/v1/virtual-transfers/create` | `POST` | [`transfers_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/transfers_api.dart) | Initiates a stock transfer between warehouse and mobile van location. |
| `/api/v1/virtual-locations` | `POST` | [`transfers_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/transfers_api.dart) | Lists active van mobile stock locations. |
| `/api/v1/returns` | `POST` | [`returns_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/returns_api.dart) | Lists and creates customer return pickings. |
| `/api/v1/scraps` | `POST` | [`scraps_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/scraps_api.dart) | Lists and creates scrap entries routing spoiled stock to scrap locations. |

### 1.8 Location Tracking & Field Supervision (`meta_ss_location_tracking`)
| Endpoint | Method | Source File | Description |
|---|---|---|---|
| `/api/v1/employee/location/sync` | `POST` | [`location_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/location_api.dart) | Ingests batches of GPS coordinates buffered in SQLite. |
| `/api/v1/manager/my_team` | `POST` | [`my_team_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/my_team_api.dart) | Retrieves status of subordinate officers (battery, attendance, last GPS fix). |
| `/api/v1/manager/employee/checkpoints` | `POST` | [`my_team_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/my_team_api.dart) | Returns historical route checkpoints for breadcrumb map playback. |

### 1.9 HR Attendance, Expenses & Leaves
| Endpoint | Method | Source File | Description |
|---|---|---|---|
| `/api/v1/hr/attendance/status` | `POST` | [`attendance_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/attendance_api.dart) | Returns active check-in status and shift start timestamp. |
| `/api/v1/hr/attendance/action` | `POST` | [`attendance_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/attendance_api.dart) | Executes geofenced clock-in / clock-out with photo verification. |
| `/api/v1/hr/expense/list` | `POST` | [`expense_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/expense_api.dart) | Lists submitted expense claims. |
| `/api/v1/hr/expense/submit` | `POST` | [`expense_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/expense_api.dart) | Submits new expense claim with base64 receipt images. |
| `/api/v1/hr/leave/request` | `POST` | [`leave_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/leave_api.dart) | Queries balances and submits multi-day leave requests with attachments. |

### 1.10 Notifications & Device Registration
| Endpoint | Method | Source File | Description |
|---|---|---|---|
| `/api/v1/device/register` | `POST` | [`device_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/device_api.dart) | Registers Firebase FCM device token against the authenticated user. |
| `/api/v1/notifications/list` | `POST` | [`notification_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/notification_api.dart) | Fetches user in-app notification inbox with unread counts. |
| `/api/v1/notifications/read` | `POST` | [`notification_api.dart`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/api/endpoints/notification_api.dart) | Marks specific notifications as read. |

---

## 2. Dart Data Models Directory

The application defines 26 structured Dart data models inside [`lib/data/models/`](file:///home/niaj/Documents/GDFL/secondary_sales_app/lib/data/models/):

| Model Name | File Path | Core Entity Mapped | Key Properties |
|---|---|---|---|
| `MobileAuthSession` | `auth/mobile_auth_session.dart` | JWT Auth Session | `token`, `refreshToken`, `userId`, `userName`, `expiresAt`, `employeeId`. |
| `DashboardSummary` | `dashboard/dashboard_summary.dart` | KPI Summary | `mtdTarget`, `mtdAchievement`, `todayVisits`, `todayOrders`, `attendanceActive`. |
| `Route` | `routes/route.dart` | `route.management` | `id`, `name`, `weekdays`, `outletsCount`, `status`. |
| `RouteLine` | `routes/route.dart` | `route.line` | `id`, `routeId`, `outletId`, `sequence`, `outletName`, `latitude`, `longitude`. |
| `VisitReason` | `routes/visit_reason.dart` | Visit Justification | `code`, `name`, `requiresPhoto`, `requiresNotes`. |
| `DeliveryItem` | `delivery_item.dart` | `stock.move.line` | `id`, `productId`, `productName`, `quantityDemand`, `quantityDone`, `lotId`. |
| `VirtualTransfer` | `inventory/virtual_transfer.dart` | `stock.picking` | `id`, `name`, `sourceLocationId`, `destLocationId`, `state`, `lines`. |
| `VirtualLocation` | `inventory/virtual_location.dart` | `stock.location` | `id`, `name`, `type`, `vanPlateNumber`, `salesOfficerId`. |
| `Warehouse` | `inventory/warehouse.dart` | `stock.warehouse` | `id`, `name`, `code`, `partnerId`. |
| `SalesEmployee` | `employees/sales_employee.dart` | `hr.employee` | `id`, `name`, `workEmail`, `workPhone`, `department`, `jobTitle`. |
| `MtOutlet` | `modern_trade/mt_outlet.dart` | MT Retail Partner | `id`, `name`, `chainName`, `latitude`, `longitude`, `address`. |
| `MtStockAudit` | `modern_trade/mt_stock_audit.dart` | MT Shelf Audit | `id`, `outletId`, `auditDate`, `items: [{productId, onShelf, backStore, facings, price}]`. |
| `MtReturnRequest` | `modern_trade/mt_return_request.dart` | MT Spoilage Return | `id`, `outletId`, `reason`, `lines: [{productId, quantity, condition}]`. |
| `ReturnScrapSummary` | `return_scrap_summary.dart` | Return/Scrap Totals | `totalReturnsCount`, `totalScrapsCount`, `totalValue`. |
| `ProductCategory` | `sales/product_category.dart` | `product.category` | `id`, `name`, `parentId`. |
| `DeliveryPrepare` | `sales/delivery_prepare.dart` | Dispatch Staging | `pickingId`, `partnerName`, `scheduledDate`, `items`. |
