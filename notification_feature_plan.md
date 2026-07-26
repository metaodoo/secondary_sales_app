# In-App Notification Center + Deep Linking — Implementation Plan

## Context

The `meta_firebase_push_notification` Odoo module already **generates and delivers** push
notifications: a `mobile.push.notification` queue, an FCM cron
(`mobile.notification.service`), device registration, and a growing set of types via
`mobile.notification.mixin` (`sale_order_confirmed/cancelled/created`,
`primary_order_submitted`, `delivery_validation_required`, `delivery_order_validated`).

What does **not** exist yet is the **consumer side**:
- No read/unread state on notifications, so no unread count.
- No API to list a user's notifications, mark them read, or fetch an unread count.
- No in-app Notification Center screen, no bell/badge entry point, no notification detail.
- The Flutter deep-link handler (`push_notification_service.dart`) is hardcoded to
  `sale_order_confirmed` + `sale.order` only, has **no foreground handler** (an incoming
  push shows nothing while the app is open), and no local-notification package.

This plan adds the full consumer experience: a read flag + unread count, a scoped list
API with filtering, an in-app Notification Center (list → detail → open the linked
record), a generic deep-link resolver, and foreground in-app banners.

**Decisions locked in:**
- Ships as a **new module `meta_ss_mobile_notifications`**, not as edits to
  `meta_firebase_push_notification`. Another developer is actively working on that module,
  so we only **`_inherit`** its `mobile.push.notification` model and add our own
  controllers/views — **zero edits to their files → no merge conflicts**. The base module
  already writes `model`/`id`/`name` into every notification's `payload_json`, so the new
  module has everything it needs without touching their generation code.
- Foreground pushes show an **in-app banner** (add `flutter_local_notifications`).
- A notification carries a **generic record reference** (`res_model` + `res_id`), not a
  sale-order-specific link. The app resolves the reference through a `model → screen`
  registry; `sale.order → OrderDetailScreen` is the first registered handler, and any
  other model can be added later without schema or API changes. Unmapped models fall back
  to the notification detail card (no navigation).
- Notifications flip to read **on open/tap**, plus a **"mark all read"** action.
- The list is inherently **per authenticated mobile user** (the JWT identity) — that is
  the employee-wise scoping in the request; no `employee_id` param is passed.

---

## Backend — new module `meta_ss_mobile_notifications`

Standalone module so `meta_firebase_push_notification` (under active development by
another dev) is never touched. It only **extends** `mobile.push.notification` via
`_inherit` and adds its own controllers/views.
`depends = ['meta_firebase_push_notification', 'meta_ss_rest_api']`.

### 1. Module scaffold
`__manifest__.py` ("Meta SS Mobile Notifications", v18.0.1.0.0, depends above, `data:
['views/notification_views.xml']`), `__init__.py`, `models/__init__.py`,
`controllers/__init__.py`. Mirror the `meta_ss_chatter_attribution` manifest style.

### 2. Extend `mobile.push.notification` — `models/mobile_push_notification.py`
`_inherit = 'mobile.push.notification'`. Add:
- `is_read = fields.Boolean(default=False, index=True)`
- `read_at = fields.Datetime()`
- **Generic record reference** (Odoo `mail.message` idiom):
  `res_model = fields.Char(index=True)`, `res_id = fields.Integer(index=True)`.
- Override `create()` to populate `res_model`/`res_id` when not supplied — read
  `model`/`id` from `payload_json`. The base mixin already writes `model`/`id`/`name` into
  `payload_json` for every notification, so this needs **no change to their mixin**.
  (No `post_init_hook` backfill and no `sale_order_id` fallback — the project isn't live
  yet, so there's no legacy data to migrate.)
- **Keep the base's unique constraint as-is** — `res_model`/`res_id` are a queryable
  cache, not the dedup key. No constraint surgery, no `ir.model.access.csv` change
  (base already grants internal users CRUD; controller uses the sudo integration env).

### 3. Consumer controller — `controllers/notification.py`
Register in the new module's `controllers/__init__.py`. Mirror `controllers/device.py`
(from the base module): `type="json"`,
`auth="user"`, `@mobile_api_error_boundary`, identity via
`get_mobile_api_context(payload, require_employee=False)`. **Every domain is constrained
by `mobile_user_id == _mobile_user.id`** so a user only ever sees/marks their own rows.
Model access via `api_env['mobile.push.notification'].sudo()`.

- `POST /api/v1/mobile/notifications` — list. Params: `limit` (default 20, cap 50),
  `offset`, optional `notification_type`, `only_unread` bool. Order `create_date desc`.
  Returns `{success, api_version, data: {notifications: [...], unread_count, total}}`
  where each item = `{id, type, type_label, title, body, is_read, created_at,
  link: {model, id, name, sale_type, action_link}}`. `link.model`/`link.id` come from the
  `res_model`/`res_id` columns; `name`/`action_link` from `payload_json`; `sale_type` is
  derived from `notif.sale_order_id.sale_type` when `res_model == 'sale.order'` (so no
  payload/mixin change is needed). `link` is `null` when there is no record reference.
- `POST /api/v1/mobile/notifications/unread-count` — lightweight badge fetch →
  `{success, data: {unread_count}}`.
- `POST /api/v1/mobile/notifications/mark-read` — param `notification_ids` (list).
  Sets `is_read=True, read_at=now` for the user's matching rows → returns new
  `unread_count`.
- `POST /api/v1/mobile/notifications/mark-all-read` — marks all the user's unread rows
  read → `{success, data: {unread_count: 0}}`.

The in-app list is independent of FCM delivery state (shows `pending`/`sent` alike) — the
user should see a notification even if the push failed.

### 4. Admin view — `views/notification_views.xml`
Inherit the base `meta_firebase_push_notification.view_mobile_push_notification_tree` via
xpath to add an `is_read` column + an "Unread" filter. The new module owns this file; the
base `menu.xml` is untouched.

---

## Flutter — `secondary_sales`

### A. Endpoints — `lib/core/constants.dart`
Add alongside the existing `mobileDevice*Endpoint` entries:
`mobileNotificationsEndpoint`, `mobileNotificationsUnreadCountEndpoint`,
`mobileNotificationsMarkReadEndpoint`, `mobileNotificationsMarkAllReadEndpoint`.

### B. Model — `lib/data/models/notifications/app_notification.dart`
`AppNotification` { id, type, typeLabel, title, body, isRead, createdAt,
`NotificationLink? link` } + `fromJson`. `NotificationLink` is the **generic record
reference**: { `String model` (res_model), `int recordId` (res_id), `String? name`,
`String? saleType`, `String? actionLink` }. It is model-agnostic — nothing here is
sale-order-specific.

### C. API extension — `lib/data/api/endpoints/notification_api.dart`
`extension NotificationApi on ApiService` (`part of '../api_service.dart'`, register the
`part` in `api_service.dart`), mirroring `endpoints/device_api.dart`'s use of `_post`:
`fetchNotifications({limit, offset, type, onlyUnread})`, `fetchUnreadCount()`,
`markNotificationsRead(List<int> ids)`, `markAllNotificationsRead()`.

### D. Provider — `lib/features/notifications/notification_provider.dart`
`ChangeNotifier` following the existing `updateAuth({accessToken, sessionId, employeeId})`
+ `clearData()` pattern (see `RouteProvider`/`DashboardProvider`). State: `notifications`,
`unreadCount`, `isLoading`, `error`, pagination (`hasMore`, offset). Methods: `refresh()`,
`loadMore()`, `refreshUnreadCount()`, `markRead(id)`, `markAllRead()`,
`addFromPush(AppNotification)` (prepend + bump count for foreground pushes).
Register in `main.dart` as `ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>`
(same shape as the other proxy providers).

### E. UI
- `lib/features/notifications/screens/notifications_screen.dart` — full-screen list:
  filter chips (All + per type), pull-to-refresh + infinite scroll (`loadMore`), rows show
  title/body/relative time + unread dot; tap → `markRead` then deep-link via the shared
  router. AppBar action "Mark all read". Shows latest N (default 20) with load-more.
- `lib/features/notifications/screens/notification_detail_screen.dart` — detail card
  (title, body, type, timestamp) + a primary **"Open record"** button, shown whenever the
  notification has a `link` whose `model` has a registered handler (label can be
  model-aware, e.g. "Open Sale Order" for `sale.order`). Tapping it runs the same
  `NotificationRouter`. Satisfies "button to show detail + button to enter the record".
- **Bell + badge** in the dashboard AppBar `actions:`
  (`home_dashboard_screen.dart` ~L399, beside `ProfileAvatar`): badge = `unreadCount`,
  tap opens `NotificationsScreen`. Call `refreshUnreadCount()` on dashboard load and on
  app resume.

### F. Deep-link + foreground handling
New file `lib/features/notifications/notification_router.dart` +
edits to `lib/core/services/push_notification_service.dart`.
- **`NotificationRouter`** = a registry keyed by the Odoo model string, whose values are
  **handler functions** (not plain widget builders — the app's detail screens have
  heterogeneous constructors, e.g. `OrderDetailScreen(orderId, fallbackName, saleType)`
  vs `VirtualTransferDetailScreen(initialTransfer)` which needs a full object).
  ```dart
  typedef NotificationOpener =
      Future<void> Function(NavigatorState nav, NotificationLink link);
  final Map<String, NotificationOpener> _registry = { ... };
  ```
  Three handler shapes cover everything:
  - **id-only screens** → build directly, e.g.
    `'sale.order': (nav, link) => nav.push(OrderDetailScreen(orderId: link.recordId,
    fallbackName: link.name, saleType: link.saleType ?? 'primary'))`.
  - **object/context screens** → `async` handler: fetch the record via that feature's
    provider using `link.recordId`, then push; on failure fall back to the feature's list.
  - **no registered handler / `link == null`** → fall back to the notification detail card
    (no navigation, never a crash).
- `NotificationLink` is built from FCM `message.data` **or** an `AppNotification.link` —
  both expose `model` + `recordId`, so the push-tap handler and in-app list/detail taps
  call the **same** `NotificationRouter.open(navigator, link)`. This **preserves the
  existing `sale_order_confirmed` deep-link** as the first registry entry. Adding a record
  type later = one registry line (+ any extra payload field its screen needs).
- The router lives in its own file (imports the feature detail screens + `appNavigatorKey`)
  so `push_notification_service.dart` stays thin — it just maps `message.data` → link →
  router.
- Add `FirebaseMessaging.onMessage` (foreground) → show a local notification via
  `flutter_local_notifications` **and** notify the provider (`addFromPush` /
  `refreshUnreadCount`).
- Add a top-level `@pragma('vm:entry-point')` background handler registered with
  `FirebaseMessaging.onBackgroundMessage(...)` in `main()`.
- Init `flutter_local_notifications` (Android channel + tap callback → `NotificationRouter`).
- Wire the provider into the static service the same way `ApiService.onTokenExpired` is
  registered in `main.dart` (a static callback the service invokes on push).

### G. `pubspec.yaml`
- Add `flutter_local_notifications` (version compatible with the current
  `firebase_messaging: ^15.0.0` / Flutter SDK). Android 13+ notification permission is
  already prompted via FCM; confirm the channel is created.

---

## Files (create ✚ / modify ✎)

Backend — all ✚ new, inside a new module `meta_ss_mobile_notifications/`
(**no edits to `meta_firebase_push_notification`**):
- ✚ `__manifest__.py`, `__init__.py`, `models/__init__.py`, `controllers/__init__.py`
- ✚ `models/mobile_push_notification.py` (`_inherit`: is_read, read_at, res_model, res_id, create() backfill)
- ✚ `controllers/notification.py` (4 endpoints)
- ✚ `views/notification_views.xml` (inherited tree: is_read column + Unread filter)

Flutter:
- ✎ `lib/core/constants.dart` (4 endpoints)
- ✚ `lib/data/models/notifications/app_notification.dart`
- ✚ `lib/data/api/endpoints/notification_api.dart`  ✎ `lib/data/api/api_service.dart` (part)
- ✚ `lib/features/notifications/notification_provider.dart`
- ✚ `lib/features/notifications/screens/notifications_screen.dart`
- ✚ `lib/features/notifications/screens/notification_detail_screen.dart`
- ✎ `lib/features/dashboard/screens/home_dashboard_screen.dart` (bell + badge)
- ✚ `lib/features/notifications/notification_router.dart` (model → handler registry)
- ✎ `lib/core/services/push_notification_service.dart` (foreground/background, local notifs, delegate to router)
- ✎ `lib/main.dart` (register provider, background handler, service↔provider wiring)
- ✎ `pubspec.yaml` (flutter_local_notifications)

---

## Verification

Backend:
1. Install the new module: restart Odoo with `-i meta_ss_mobile_notifications`; confirm
   `is_read`/`read_at`/`res_model`/`res_id` exist on `mobile.push.notification` (the
   inherited "Push Notification Queue" tree shows the `is_read` column).
2. Exercise each endpoint (via the app, or JSON-RPC with an authenticated session):
   list returns only the caller's rows + correct `unread_count`; mark-read /
   mark-all-read decrement it; `notification_type` and `only_unread` filters work.

End-to-end:
3. Create a sale order from the app → confirm it in Odoo → cron delivers the push →
   app: bell badge increments, foreground banner appears (app open), tapping the push or
   the list row opens the correct `OrderDetailScreen`, and the row flips to read.
4. Regression: the pre-existing `sale_order_confirmed` background-tap deep link still
   opens the order.

App build gate:
5. `flutter analyze` and a debug `flutter build` (or `flutter run`) both pass.

---

## Out of scope (v1)
- Additional `model → screen` registry handlers beyond `sale.order`. The schema, API, and
  router are already generic (any `res_model`/`res_id`), so new record types are added by
  registering a handler later — no migration needed. Role-specific workflow screens
  implied by `action_link` (finance-confirm, supply-chain validate) are among these.
- Real-time badge via a separate silent data-push channel — the badge refreshes on push
  receipt, app resume, and dashboard load.
