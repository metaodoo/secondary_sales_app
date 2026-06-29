# Flutter App Review — Secondary Sales

**Overall: 6.8 / 10**

---

## Architecture & Structure — 8.0 / 10

The layering is correct and clean: `services/` handles HTTP, `providers/` handles state, `models/` handles deserialization, `screens/` handles UI. The `ChangeNotifierProxyProvider` chain in `main.dart` is the right pattern for propagating auth tokens to other providers when login/logout happens — this is done correctly.

`AuthGate` cleanly handles the three states (initialising, unauthenticated, authenticated) with no race conditions. `AuthProvider.restoreSession()` correctly checks expiry and calls `refreshSession()` before surfacing the session to the app. The `mounted` guard in `login_screen.dart` after the async login call is correct.

---

## Critical Issues

### 1. Two separate hardcoded database name constants

```dart
// ApiService:
static const String _hardcodedDb = 's_sales';

// AppConstants:
static const String dbName = 's_sales';
```

`ApiService` has its own `_hardcodedDb` independent from `AppConstants.dbName`. `AuthService` uses `AppConstants.dbName` while `ApiService` uses its own. If the DB name changes, one will be missed. Use one source of truth.

---

### 2. `defaultEmployeeId = 7` silently poisons all requests

```dart
// AppConstants:
static const int defaultEmployeeId = 7;

// ApiService:
int get _activeEmployeeId => _employeeId ?? AppConstants.defaultEmployeeId;
```

When `_employeeId` is null (auth not yet propagated, or provider created before login), all API calls silently use employee ID 7 instead of failing. This means stale data or another employee's data is fetched without any error. The fallback should throw, not default.

---

### 3. Each provider creates its own `ApiService` instance

```dart
// PrimarySaleProvider, InventoryProvider, EmployeeProvider, RouteProvider:
final ApiService _apiService = ApiService();
```

Four separate `ApiService` instances means four separate `http.Client()` pools. Worse, when `updateAuth()` is called on a provider, it only updates that provider's instance — if the `ChangeNotifierProxyProvider` fires in a different order than expected, one provider could be making calls with a stale token while another has the new one. `ApiService` should be a single shared instance injected through the constructor or passed from `main.dart`.

---

### 4. `_buildTransferLotPayload` makes a hidden network call inside `createVirtualTransfer`

```dart
// ApiService:
if (line.product.requiresLots) {
  payload['lot_lines'] = await _buildTransferLotPayload(line, destinationLocationId);
}
```

`_buildTransferLotPayload` calls `getTransferProductLots` — a network request — silently inside the creation call. The user tapped "Create Transfer" expecting one request. If lot-fetching fails (network blip, lot exhausted between screens), they get a confusing error. Lot selection should happen in the UI before submission, not be auto-resolved at submit time.

---

## Security Issues

### 5. Tokens stored in `shared_preferences`

Both `access_token` and `refresh_token` are stored via `SharedPreferences`, which writes to an unencrypted XML file on Android. Any app with root access can read it. The industry standard for mobile token storage is `flutter_secure_storage` (backed by Android Keystore / iOS Keychain). Given `intl` and `google_fonts` are already in the dependency list, adding `flutter_secure_storage` is straightforward.

---

### 6. Default base URL uses `http://`

```dart
static const String baseUrl = String.fromEnvironment(
  'ODOO_BASE_URL',
  defaultValue: 'http://127.0.0.1:8069',
);
```

If the app is ever built without explicitly setting `ODOO_BASE_URL`, all traffic — including tokens in Authorization headers — goes over plain HTTP. The default should be `https://` or the build should fail without the variable being explicitly provided.

---

## Code Quality Issues

### 7. Manual date formatting when `intl` is already a dependency

```dart
// Repeated in multiple places:
'${dateFrom.year.toString().padLeft(4, '0')}-${dateFrom.month.toString().padLeft(2, '0')}-...'
```

`intl` is declared in `pubspec.yaml`. Replace these with `DateFormat('yyyy-MM-dd').format(date)`.

---

### 8. Mixed model types — some routes/outlets use raw `Map<String, dynamic>`

`getRoutes`, `getRouteDetail`, `updateRoute`, `getOutlets` all return `Map<String, dynamic>` instead of typed model classes. `RouteProvider` does wrap them in `RouteModel.fromMap`, but `getOutlets` stays as raw maps throughout the call chain into the UI. This bypasses compile-time type safety for a significant part of the app.

---

### 9. `_asInt` and `_asMap` return silent zero/empty-map defaults

```dart
int _asInt(dynamic value) {
  ...
  return int.tryParse(value?.toString() ?? '') ?? 0;  // ← silent 0
}
```

When the server omits a required field (like an ID), the model silently gets `id = 0` instead of failing loudly. A record with id `0` will then silently fail in subsequent operations. A failed parse should either throw or return a nullable result.

---

### 10. `createSalesOrder` is a redundant wrapper

```dart
Future<bool> createSalesOrder(...) async {
  await createPrimarySalesOrder(...);
  return true;
}
```

This wraps `createPrimarySalesOrder` to return `bool` instead of `PrimaryOrder`, discarding the created order object. Either consolidate to one function or remove the wrapper.

---

### 11. Dart 3.9 feature suppressed with file-level lint ignore

```dart
// ignore_for_file: use_null_aware_elements
```

The `?value` syntax in map literals (`'warehouse_id': ?warehouseId`) is a Dart 3.9+ feature. The file suppresses the warning rather than using an explicit `if (warehouseId != null) 'warehouse_id': warehouseId` pattern that works on all SDK versions. This is fine if the team is committed to Dart 3.9+, but should be a deliberate and documented decision, not a lint suppression.

---

## What's Working Well

- `AuthService` takes an injectable `http.Client?` — testable by design
- `AuthProvider.logout()` clears local state first, then attempts server logout, with correct silent catch for network errors
- Debug prints are properly gated behind `kDebugMode`
- All requests have a 20-second timeout
- `MobileAuthSession.fromMap` correctly handles Odoo's pattern of returning `false` instead of `null` for empty fields
- `AuthGate` pattern is clean with no flash-of-wrong-content

---

## Summary

| # | Issue | Severity |
|---|-------|----------|
| 1 | Two separate DB name constants | Medium |
| 2 | `defaultEmployeeId = 7` fallback silently poisons requests | High |
| 3 | Multiple `ApiService` instances, one per provider | High |
| 4 | Hidden network call inside `createVirtualTransfer` | High |
| 5 | Tokens in `shared_preferences` instead of secure storage | High |
| 6 | Default base URL uses `http://` | Medium |
| 7 | Manual date formatting, `intl` unused | Low |
| 8 | Mixed model types (raw maps vs typed classes) | Medium |
| 9 | `_asInt` / `_asMap` silent zero/empty defaults | Medium |
| 10 | `createSalesOrder` redundant wrapper | Low |
| 11 | Dart 3.9 feature suppressed with file-level lint ignore | Low |

The foundations are solid — the auth flow, provider architecture, and API contract alignment with the backend are all well done. The most important fixes before production are **#2** (defaultEmployeeId fallback), **#3** (shared ApiService instance), **#4** (hidden network call in create), and **#5** (secure token storage).
