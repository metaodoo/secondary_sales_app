# App-Side Access Audit — what's actually gated vs not

Audit of how the Flutter app enforces the module/access config. A catalog key only
*does something* if some widget checks `canView(key)` / `canDo(key)` / `PermissionGate` (or
an `auth` getter that maps to it). A key that's synced to Odoo but unchecked in the app
**cannot be controlled** — enforcing or hiding it has zero visible effect.

**Coverage: 32 of 66 keys wired** (was 25). Pass 1 fixed the visible-contradiction nav/
Settings items; Pass 2 added the create/action buttons below.

**Pass 2 wired (✅):** `sales.create_primary` + `sales.order_create` (primary & secondary
create buttons), `sales.delivery_validate`, `transfers.create`, `transfers.cancel`,
`employees.create`, `routes.create` (header + FAB), `routes.add_outlet`, `visits.check_out`.

**Pass 2 still to wire (buttons are FAB/entry-style, need per-file location):**
`contacts.distributor_create` (dealers tab), `contacts.outlet_create` (outlets list),
`visits.check_in` (check-in happens in the outlet/visit flow, not check_in_screen),
`transfers.create_location`, and the virtual-transfer-list empty-state create button.
(`sales.order_confirm`/`order_cancel` have **no button** in the app — leave unwired.)

**Pass 3 (deep-screen route guards):** optional belt-and-suspenders — every deep screen's
*entry* is now gated, so guarding the screens themselves is lower priority.

---

## ✅ Wired (respond to config today)

**Screens (15):** module.primary, module.secondary, module.attendance, module.leave,
module.expense, contacts.dealers, sales.primary_list, sales.deliveries_list,
sales.secondary_orders_list, contacts.outlets_list, routes.list, van_loading.list,
routes.visits_list, returns.list, scraps.list

**Actions (10):** returns.view_all, returns.edit_so_qty, returns.edit_qc_qty,
returns.edit_effective_qty, hr.skip_attendance_geo, returns.create, scraps.create,
hr.leave_create, hr.expense_create, transfers.validate

---

## 🐞 Category A — "Unconditional UI" (the Secondary-card bug class)

Visible entry points hardcoded to show **regardless of config**. Highest priority — these
actively contradict the access rules. (Secondary module card was one of these; already
fixed.)

| # | Where | Problem | Status |
|---|---|---|---|
| A1 | **Routes** bottom-nav item (Secondary shell) | no access check — always shown | ✅ fixed (Pass 1) — `screenKey` gate |
| A2 | **Van Operations** bottom-nav item (Secondary shell) | same — always shown | ✅ fixed (Pass 1) — `screenKey` gate |
| A3 | **Settings → Attendance** | duplicate entry into HR; bypasses `module.attendance` gate | ✅ fixed (Pass 1) — `canView(moduleAttendance)` |
| A4 | **Settings → Leave Request** | bypasses `module.leave` gate | ✅ fixed (Pass 1) — `canView(moduleLeave)` |
| A5 | **Settings → Sales Officers** | opens employee admin; ungated (`employees.list`) | ✅ fixed (Pass 1) — `canView(salesOfficerList)` |
| A6 | **Dashboard → Delivery (Secondary)** card | ungated (shares Primary's key) | ⏳ needs own key `screen.secondary.delivery` |
| A7 | **Dashboard → Scrap Operation** card | ungated (same reason) | ⏳ needs own key `screen.secondary.scrap` |
| A8 | **Settings → Sync Access Catalog** | shown to all; server rejects non-admins, so low risk | ⏳ deferred (low risk) |

Also gated the **Secondary module card** on the picker (`module_selection_screen.dart`) — the
original instance of this bug.

**Fix pattern:** nav items → add access checks to `app_shell_config` (A1/A2); Settings items
→ wrap with `canView`/`canDo` (A3–A5, A8); cards A6/A7 → need their own keys
(`screen.secondary.delivery` / `screen.secondary.scrap`) to gate independently of Primary.

---

## 🚫 Category B — Action buttons defined but NOT gated

The key exists and can sit in a module, but the button never checks it → enforcing does
nothing. (This is the "sale order create" case.)

| Action key | Button / where |
|---|---|
| `action.sales.order_create` | Create/confirm order in the Secondary order flow (`order_creation_screen`, `order_tab`) |
| `action.sales.order_confirm` | Order detail confirm (`order_detail_screen`) |
| `action.sales.order_cancel` | Order detail cancel |
| `action.sales.delivery_validate` | Validate delivery (`validate_delivery_screen`) |
| `action.transfers.create` | Create transfer / van load (`create_virtual_transfer_screen`, `van_load_form_screen`) |
| `action.transfers.cancel` | Transfer detail cancel |
| `action.routes.create` | Create route (`create_route_screen`) |
| `action.routes.add_outlet` | Add outlet to route (`route_detail_screen`) |
| `action.contacts.distributor_create` | Create distributor (`create_distributor_screen`) |
| `action.contacts.outlet_create` | Create/edit outlet (`create_outlet_screen`, `edit_outlet_screen`) |
| `action.employees.create` | Create sales officer (`create_sales_officer_screen`) |
| `action.visits.check_in` | Check-in (`check_in_screen`) |
| `action.visits.check_out` | Check-out |

**Fix pattern:** wrap each button with `PermissionGate(resourceKey: AppAction.x, child: …)`
or `if (auth.canDo(AppAction.x))`.

---

## 🚫 Category C — Screens defined but NOT gated at their entry

Reachable screens whose entry point doesn't check the key. Some are *indirectly* protected
(only reachable through an already-gated parent); others have an ungated entry and are fully
exposed. Notable fully-exposed areas:

- **Virtual Transfers**: `transfers.list`, `transfers.detail`, `transfers.create`,
  `transfers.create_location` — no gated entry (reached from Van Operations, which is itself
  ungated in nav). Whole area bypasses config.
- **Employees admin**: `employees.list`, `employees.detail`, `employees.create` — reached via
  the ungated Settings → Sales Officers (A5).
- **Van loading**: `van_loading.form`, `van_loading.location_detail`.
- **Routes CRUD**: `routes.detail`, `routes.create`, `routes.create_outlet`,
  `routes.new_joint_visit`.
- **Secondary sales sub-screens**: `sales.order_create`, `sales.create_primary`,
  `sales.order_detail`, `sales.product_selection`, `sales.validate_delivery`.
- **Contacts sub-screens**: `contacts.distributor_detail`, `contacts.create_distributor`,
  `contacts.edit_outlet`.
- **Create screens**: `returns.create`, `scraps.create` (buttons gated, screens not — fine
  since the button is the only entry).
- **HR screens**: `hr.attendance`, `hr.leave`, `hr.expense` — gated at the module card, but
  ALSO reachable via ungated Settings items (A3/A4).

**Fix pattern:** gate the **entry point** (card/nav/button) for each; a full route-guard on
the screen itself is belt-and-suspenders (optional).

---

## ⚪ Category D — Intentionally ungated (not gaps)

- `screen.dashboard`, `screen.settings` — core, meant to be visible to everyone (unattached
  in the module model). Correct as-is.

---

## Recommended fix passes (priority order)

1. **Category A (the visible contradictions)** — nav items A1/A2, Settings items A3–A5.
   Small, high-impact; stops config from being visibly ignored.
2. **Category B action buttons** — wrap the ~13 create/confirm/cancel/validate/check-in
   buttons with `PermissionGate`. Makes those keys real.
3. **Category C deep screens** — gate entries for Transfers, Employees, Routes CRUD, Van
   forms.
4. **A6/A7** — decide whether Secondary Delivery/Scrap need independent keys (adds 2 catalog
   entries + a re-sync).

Each is a one-time wrap; all use the existing `canView`/`canDo`/`PermissionGate`. After all
four passes, every catalog key is enforceable and the "unconditional UI" class is gone.
