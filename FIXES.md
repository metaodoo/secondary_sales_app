# Fixes & Hardening Backlog — Secondary Sales

Tracked list of things to fix, ordered by priority. Grounded in a code study on
2026-07-05. Current overall assessment: **~7/10** — strong architecture, gaps in
production hardening (tests, typing, security).

**Standing constraint:** no existing feature may be hampered by any change. Make
fixes behavior-neutral by default; if a change *could* alter runtime behavior,
surface it and get a decision first. After each change run `flutter analyze`
(expect 0 errors) and `flutter build apk --debug`.

Legend: `[ ]` open · `[x]` done · `[~]` in progress

---

## Already fixed (verified in code — do NOT redo)

These were flagged in the old `REVIEW.md` but the codebase has since moved past them:

- [x] Single shared `ApiService.instance` singleton (was one instance per provider). — REVIEW #3
- [x] `_activeEmployeeId` throws when employee id is null (was silently defaulting to employee 7). — REVIEW #2
- [x] Lot resolution is an explicit up-front step (`resolveTransferLotInputs`), not a hidden network call inside `createVirtualTransfer`. — REVIEW #4
- [x] Single dynamic DB-name source from the connection-setup screen (no hardcoded `_hardcodedDb`). — REVIEW #1
- [x] Base URL no longer defaults to a hardcoded `http://` host; entered at first-run connection setup. — REVIEW #6 (partial)

---

## P0 — Block a production release

- [ ] **Secure token storage.** Access + refresh tokens are stored in
  `shared_preferences` (unencrypted XML on Android, readable with root). Move to
  `flutter_secure_storage` (Android Keystore / iOS Keychain).
  - Where: `features/auth/auth_provider.dart` (`_storeSession`, `restoreSession`,
    `_clearStoredSession`), `core/constants.dart` (storage keys).
  - Behavior risk: **migration** — existing logged-in testers would be logged out
    once on upgrade unless a one-time read-old / write-new migration is added.
    Decide before implementing. — REVIEW #5

- [ ] **Enforce JWT server-side; stop trusting `employee_id` from request params.**
  Business endpoints currently scope by an `employee_id` passed in the JSON-RPC
  params, so any authenticated caller can request another employee's data by
  changing the value. Validate the bearer token on business endpoints and derive
  the employee from it.
  - Where: mostly backend (Odoo `meta_ss_rest_api`); app-side, stop sending
    `employee_id` once the server derives it. Coordinated app+backend change.

---

## P1 — High value, do soon

- [ ] **Add a real test suite.** Only `test/widget_test.dart` exists (22 lines, the
  untouched Flutter template). Prioritize the money/inventory logic:
  - FIFO lot allocation (`ApiService.resolveTransferLotInputs`) — fresh/scrap split,
    exhaustion errors.
  - Model `fromMap`/`toMap` round-trips (Odoo returns `false` for empty fields).
  - Delivery validation math (`validate_delivery_screen.dart`).
  - `AuthProvider` restore/refresh/logout state transitions.

- [ ] **Type the raw-map endpoints.** 49 of ~85 endpoint methods return
  `Map<String,dynamic>` / `List<Map<String,dynamic>>` instead of models — routes,
  outlets, and all of HR flow untyped into the UI, bypassing compile-time safety.
  - Where: `data/api/endpoints/routes_api.dart`, `contacts_api.dart` (outlets),
    `leave_api.dart`, `expense_api.dart`, `attendance_api.dart`.
  - Add model classes + `fromMap`/`toMap` (also unblocks the future offline DB —
    see `OFFLINE_PLAN.md`).

---

## P2 — Consistency & correctness

- [ ] **Unify HR provider wiring with the rest of the app.** `ExpenseProvider`,
  `LeaveProvider`, `AttendanceProvider` take `AuthProvider` in their constructor and
  are created per-screen via local `ChangeNotifierProvider`, using a soft
  `_employeeId == 0` guard. Older providers use `ChangeNotifierProxyProvider` in
  `main.dart` + `updateAuth()` + throw-on-null. Pick one pattern.
  - Note: they share `ApiService.instance`, so this is a consistency issue, not a
    live bug. Low urgency.

- [ ] **Replace manual date formatting with `intl`.** 8 sites build dates with
  `.toString().padLeft(4,'0')...` even though `intl` is already a dependency. Use
  `DateFormat('yyyy-MM-dd')`.
  - Where: `data/api/endpoints/transfers_api.dart` (multiple), and others.

- [ ] **De-duplicate `createVirtualTransfer` / `updateVirtualTransfer`.** The two
  methods in `transfers_api.dart` share a near-identical line-serialization block —
  extract a private helper.

---

## P3 — Polish

- [ ] **Remove leftover thinking-out-loud comments.** e.g.
  `transfers_api.dart:281-284` ("Wait, the backend only takes one date!"). Replace
  with a clear statement of the actual contract, or delete.

- [ ] **Document the Dart 3.9 `?value` null-aware map syntax decision.** Files carry
  `// ignore_for_file: use_null_aware_elements`. Fine if the team commits to Dart
  3.9+, but make it a deliberate, documented choice rather than a blanket lint
  suppression. — REVIEW #11

- [ ] **Revisit silent zero/empty defaults in parsing.** `parse.dart` returns `0`
  for failed int parses in some paths; a missing server-side id becomes `id = 0` and
  fails silently downstream. Preserve the intentional variants (`asInt`→0,
  `asIntOrNull`, `asNonZeroInt`→null) but audit where a loud failure is safer.
  — REVIEW #9

---

## Notes

- Offline support is intentionally deferred until the online app + API contract are
  stable — see `OFFLINE_PLAN.md`. Building `toMap()` alongside `fromMap()` now (P1
  typing work) directly serves that later.
- The stale `REVIEW.md` (rated 6.8) predates the P0-adjacent fixes above; treat this
  file as the current source of truth for outstanding work.
</content>
</invoke>
