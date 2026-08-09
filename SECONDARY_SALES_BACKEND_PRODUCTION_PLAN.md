# Secondary Sales Backend Production Readiness Plan

Date: July 31, 2026
Target: Raise the backend from current approximate readiness `4/10` to `8+/10`
Scope: Odoo 18 backend modules powering the Secondary Sales mobile app.

Primary modules in scope:

- `meta_api_user`
- `meta_ss_rest_api`
- `meta_ss_sales`
- `meta_ss_transfer`
- `meta_ss_route_management`
- `meta_ss_contact`
- `meta_ss_employee`
- `meta_ss_attendance`
- `meta_ss_location_tracking`
- `meta_ss_expense`
- `meta_ss_leave_request`
- `meta_ss_mobile_notifications`
- supporting access and mobile-policy layers

## 1. Executive Summary

The backend has a strong business-domain foundation, but it is not production-ready as-is because there are unresolved issues in authentication, authorization, territory scoping, and inventory consistency.

The fastest realistic path to `8+/10` is:

1. Fix critical auth and token risks.
2. Enforce real server-side authorization and record scoping everywhere.
3. Standardize stock-availability semantics across all transfer and delivery flows.
4. Add automated tests around permissions, territory isolation, and stock movements.
5. Define release gates so config mistakes cannot silently weaken production.

If executed properly, the system can become production-ready without redesigning the whole architecture.

## 2. Current State Summary

### What is already good

- The codebase is modular and business-oriented.
- The REST layer is separated from the normal Odoo UI.
- Mobile endpoints share common helpers for auth, context, and error handling.
- Transfer flows for returns and scraps already encode business stages clearly.
- The app-specific access-key system is better than relying on UI visibility alone.

### What blocks production readiness today

- Anonymous session bootstrap into an internal Odoo user.
- JWT secret can fall back to a hard-coded literal.
- Core mobile rule enforcement exists, but key endpoints have it commented out.
- Several write flows trust ids from the client without enforcing territory ownership.
- Stock calculations are not centralized and differ across flows.
- Update flows do not always re-run the same validations as create flows.

## 3. Definition Of Production Ready

For this backend, production-ready means:

- No unauthenticated or weakly authenticated path can create a privileged server session.
- A user cannot read or mutate data outside their assigned employee, route, distributor, outlet, or operation scope.
- Stock-impacting endpoints use one consistent quantity model and fail safely.
- Permission behavior is deterministic across all endpoints.
- Misconfiguration cannot silently weaken security.
- Critical business flows have automated tests.
- Deployment has explicit release checks and rollback safety.

## 4. Priority Roadmap

### Phase 0: Immediate Risk Containment

Target timeline: same day to 2 days

- Disable or lock down `/api/v1/auth/bootstrap-session`.
- Remove hard-coded JWT fallback behavior.
- Audit the configured integration user and reduce its permissions.
- Review currently exposed mobile endpoints and temporarily disable high-risk ones if needed.

### Phase 1: Authentication And Authorization Hardening

Target timeline: 3 to 5 days

- Enforce record rules and model access checks across all mobile endpoints.
- Standardize employee, distributor, outlet, and route scoping.
- Remove trust in arbitrary ids from client payloads unless they are validated against caller scope.

### Phase 2: Inventory Integrity Hardening

Target timeline: 4 to 7 days

- Centralize stock quantity semantics.
- Ensure create and update flows run the same business validations.
- Enforce lot-level availability checks everywhere.
- Add concurrency-safe validation around reservations and revalidation.

### Phase 3: Testing And Release Controls

Target timeline: 4 to 7 days

- Add endpoint-level permission tests.
- Add transfer and delivery stock tests.
- Add environment validation checks for secrets and integration-user safety.
- Add pre-release checklist and block deployment on failed gates.

## 5. Detailed Remediation Work

## 5.1 Authentication And Session Security

### Problem A: Anonymous bootstrap creates an internal Odoo session

Risk:

- A caller can hit `/api/v1/auth/bootstrap-session` without credentials.
- That route creates a real backend session for the configured integration user.
- If the session cookie is accepted elsewhere, this is effectively a privileged auth bypass.

Required fix:

1. Remove this endpoint from production entirely if it is only for setup or debugging.
2. If it must exist:
   - require a signed server-to-server secret
   - restrict by IP allowlist
   - add nonce/replay protection
   - log every use
   - disable it with config by default
3. Do not create a browser-style Odoo session for anonymous callers.
4. If bootstrap is needed for mobile, return only a narrow-lived bootstrap token, not an internal user session cookie.

Acceptance criteria:

- Anonymous request cannot obtain an authenticated Odoo session.
- Production config defaults to endpoint disabled.
- Security test proves bootstrap is rejected without explicit trusted configuration.

### Problem B: Hard-coded JWT fallback secret

Risk:

- If config is weak, tokens are signed with a known literal.
- That makes forged access tokens feasible.

Required fix:

1. Delete the hard-coded fallback string.
2. Fail startup or fail token issuance when `meta_api_user.jwt_secret` is missing or too short.
3. Require a minimum 32-byte random secret from environment or secure config.
4. Add secret rotation strategy:
   - current signing key id
   - optional previous verification key id
   - rotate without logging everyone out instantly if needed

Acceptance criteria:

- Token creation fails on weak or missing secret.
- Deployment health check fails if secret is invalid.
- No static fallback remains in source.

### Problem C: Integration user may be over-privileged

Risk:

- Even if mobile auth is correct, the effective ORM env may still be too broad.

Required fix:

1. Audit the configured integration user.
2. Strip it down to minimum required groups.
3. Prefer acting as the linked employee user when possible.
4. For flows that must use a service account, add strict explicit domain enforcement and never rely only on broad ORM rights.

Acceptance criteria:

- Documented minimal group set for integration user.
- No admin-like group on the integration user unless explicitly justified.

## 5.2 Authorization And Territory Scope Enforcement

### Core principle

UI access keys are not enough.

The backend must enforce:

- model access
- operation access
- record visibility
- create-value eligibility
- update/delete ownership rules

### Problem D: mobile rule enforcement exists but is commented out

Observed pattern:

- `check_mobile_model_access(...)` present but commented out
- `apply_mobile_rule_domain(...)` present but commented out
- `mobile_rule_domain_allows_values(...)` present but commented out

Impact:

- Permission architecture exists in theory, but live enforcement is partial.
- A missed manual domain becomes a real data leak or write-scope bug.

Required fix:

1. Decide the canonical enforcement chain for every endpoint:
   - `require_ui_access` or `require_sale_type_access`
   - `check_mobile_model_access`
   - `apply_mobile_rule_domain` for reads
   - `mobile_rule_domain_allows_values` for creates
   - explicit ownership/domain check for updates/actions
2. Restore this logic endpoint by endpoint.
3. If current mobile rule metadata is incomplete, complete the data model first instead of leaving checks disabled.

Priority endpoints:

- sale orders list/detail/create/update/action/print
- contacts list/detail/create/update/history
- route create/update/add-outlet/remove-outlet
- employee create/update
- return/scrap create/update/action

Acceptance criteria:

- No endpoint uses only access keys plus `sudo()` without scope enforcement.
- Tests prove a valid user cannot cross team or territory boundaries.

### Problem E: Secondary sale order create trusts arbitrary `outlet_id`

Risk:

- A user can create orders for outlets outside allowed territory if they know ids.

Required fix:

1. Replace raw outlet browse with a scoped helper:
   - outlet must be visible under employee routes or allowed outlet domain
   - optionally also require assigned visit context unless role explicitly bypasses it
2. Centralize outlet resolution in one helper shared by create/update/detail flows.

Acceptance criteria:

- Attempt to create an order for an out-of-scope outlet returns access or validation error.

### Problem F: Route management can attach arbitrary outlets

Risk:

- Route edit/add-outlet can connect unrelated outlets or create new outlets without proper ownership checks.

Required fix:

1. Validate outlet visibility against the requesting employee’s route or distributor scope.
2. If route has distributor binding, enforce outlet-distributor consistency if that relationship exists in the data model.
3. Separate:
   - create new outlet
   - attach existing outlet to route
4. Require dedicated permission for outlet creation inside route flow.

Acceptance criteria:

- A user cannot add an out-of-scope outlet to a route.
- A user cannot silently create new outlets through a route endpoint unless explicitly allowed.

### Problem G: Employee and distributor assignment writes are too trusting

Risk:

- Employee create/update can assign arbitrary distributors and routes that merely exist.

Required fix:

1. Validate assigned distributors and routes against the caller’s allowed management scope.
2. Add a manager/admin scope model for who can assign whom.
3. Reject cross-team assignments.

Acceptance criteria:

- Employee assignment operations are scoped by caller authority, not just object existence.

## 5.3 Inventory And Quantity Consistency

### Core principle

Define one stock language and use it everywhere.

Recommended semantic model:

- `free_qty`: on-hand minus reservations at exact source location
- `effective_qty_for_document`: `free_qty` plus the current document’s own reservation when editing/revalidating
- `gross_qty`: raw on-hand, used only for reporting/debug

### Problem H: Different endpoints use different stock semantics

Observed patterns:

- some use `available_quantity`
- some use `quantity - reserved_quantity`
- some add back current picking reservation
- some do not
- some use exact location
- some historically used `child_of`

Required fix:

1. Create a single shared stock service/helper module.
2. Expose explicit functions:
   - `get_free_qty(product, location)`
   - `get_effective_qty_for_picking(product, location, picking=None)`
   - `get_lot_free_qty(product, lot, location)`
   - `get_lot_effective_qty_for_picking(product, lot, location, picking=None)`
3. Replace direct ad hoc quant math in:
   - deliveries
   - returns
   - scraps
   - virtual transfers
   - product in-stock filters
4. Preserve exact `location_id` semantics for operational flows, since that matches business intent.

Acceptance criteria:

- One source of truth for stock calculations.
- Same product/lot shows the same availability meaning across API screens for the same flow.

### Problem I: Transfer create validates stock, update does not

Risk:

- Users can update a draft or assigned transfer into a state that create would have rejected.

Required fix:

1. Run requested-quantity validation during update as well.
2. For tracked products, revalidate each lot against effective availability.
3. Fail before unlinking and recreating moves if the new payload is invalid.
4. Consider transactional rebuild with explicit savepoint.

Acceptance criteria:

- Update path rejects the same invalid payloads that create path rejects.

### Problem J: Lot-level availability is not consistently validated

Risk:

- Total line quantity may be valid while a specific lot is over-claimed.
- Failure happens later and less clearly, or under concurrency.

Required fix:

1. Use lot-level availability helpers consistently.
2. Validate every lot line before creating move lines.
3. When editing an assigned document, use effective document-aware availability.

Acceptance criteria:

- Over-allocation of an individual lot is rejected deterministically before move creation.

### Problem K: Backorder behavior is intentionally suppressed but not clearly governed

Current behavior:

- `skip_backorder=True`
- short quantities validate without creating backorders

Required fix:

1. Confirm this is the intended business rule for:
   - deliveries
   - returns
   - scraps
   - transit validations
2. Document it explicitly.
3. If different flows need different behavior, encode that by flow instead of globally.

Acceptance criteria:

- Product owners sign off on per-flow backorder policy.
- Automated tests assert the intended result.

## 5.4 API Hardening And Safety

### Problem L: Too much `sudo()` in mobile-facing flows

Risk:

- `sudo()` is used throughout to bypass native Odoo restrictions.
- This is acceptable only if custom scope enforcement is complete and correct.
- Right now it is not complete.

Required fix:

1. Review all `sudo()` in mobile controllers and helpers.
2. Keep `sudo()` only where required by architecture.
3. Wrap every `sudo()` read/write in an explicit validated domain or object ownership check.
4. Prefer acting in constrained integration env where possible.

Acceptance criteria:

- No unscoped `sudo()` remains on sensitive read/write paths.

### Problem M: Error handling is standardized, but security failure semantics should be clearer

Required improvement:

1. Keep `@mobile_api_error_boundary`.
2. Distinguish:
   - validation error
   - authentication error
   - authorization error
   - not found due to scope
3. Avoid leaking internal details, but preserve enough client behavior to support correct UI handling.

Acceptance criteria:

- Client can differentiate invalid input from permission denial.

## 5.5 Testing Strategy Required For 8+/10

### Security tests

Must add:

- bootstrap endpoint rejects anonymous access in production mode
- token issuance fails with weak secret
- token validation fails on forged token
- refresh/logout revoke behavior works
- hidden access-key paths are denied

### Authorization tests

For every major resource:

- same-team access allowed
- cross-team read denied
- cross-team write denied
- out-of-scope distributor denied
- out-of-scope outlet denied
- out-of-scope route denied

Target modules:

- sale orders
- contacts
- routes
- employees
- returns
- scraps
- deliveries

### Inventory tests

Must cover:

- exact-location stock checks
- tracked vs untracked products
- own reservation add-back during edit
- lot FIFO assignment
- return create/update/validate
- scrap create/update/validate
- delivery validation with partial quantity
- no accidental negative or phantom availability

### Regression tests for known fixes

Must codify:

- return list visibility for transit-source legs
- app validate requiring `type`
- assigned transit return detail showing usable qty
- exact-location semantics instead of `child_of` in operational flows

### Concurrency tests

Recommended:

- two users claiming same tracked lot
- update after reservation changed
- validate after stock changed
- route/outlet assignment race cases

## 5.6 Operational Readiness

### Configuration hardening

Before production:

- require strong `meta_api_user.jwt_secret`
- review `meta_api_user.integration_user_id`
- disable bootstrap endpoint or guard it heavily
- verify mobile access-key catalog is synced and complete
- verify hidden button/resource configuration matches intended roles

### Logging and audit

Must log:

- authentication success/failure
- token refresh/logout
- access-denied events
- stock-impacting create/update/validate actions
- role or assignment changes

### Monitoring

Add dashboards/alerts for:

- repeated auth failures
- repeated access-denied spikes
- transfer validation failures
- negative stock attempts
- API 500 error rate

### Deployment gate

Release should be blocked unless:

- auth checks pass
- permission tests pass
- stock regression tests pass
- required secrets are present
- bootstrap route policy is compliant

## 6. Recommended Implementation Order

### Sprint 1: Security blockers

- remove or lock bootstrap endpoint
- remove hard-coded JWT fallback
- audit integration user
- add config health checks

Expected result:

- biggest production blocker removed

### Sprint 2: Authorization framework activation

- restore rule/model enforcement in sales/contact endpoints
- add scoped outlet/distributor/route resolution helpers
- patch employee and route write flows

Expected result:

- users cannot cross team or territory boundaries

### Sprint 3: Inventory standardization

- centralize quantity helpers
- unify exact-location logic
- add lot-level validation on update and validate
- patch remaining transfer/delivery inconsistencies

Expected result:

- stock math becomes predictable and testable

### Sprint 4: Test suite and release controls

- add permission tests
- add stock/transfer tests
- add production config checks
- add release checklist

Expected result:

- backend becomes safely releasable

## 7. Suggested Ratings After Fixes

If the above work is completed well:

- Architecture/modularity: `8/10`
- Business-flow coverage: `8/10`
- Security/access control: `8/10`
- Inventory integrity: `8/10`
- Maintainability: `7.5/10`
- Production readiness overall: `8 to 8.5/10`

Without fixing auth and authorization first, no other improvement should be used to justify a production-grade score.

## 8. Concrete Checklist

### Blockers

- [ ] Disable or harden `/api/v1/auth/bootstrap-session`
- [ ] Remove hard-coded JWT fallback secret
- [ ] Enforce strong JWT secret at config/startup
- [ ] Audit and reduce integration-user privileges

### Access control

- [ ] Re-enable model access checks on mobile endpoints
- [ ] Re-enable rule-domain application on read endpoints
- [ ] Re-enable create-value rule checks on create endpoints
- [ ] Add scoped helper for outlet resolution
- [ ] Add scoped helper for distributor resolution in all write flows
- [ ] Add scoped helper for route ownership in all route mutations
- [ ] Add scoped helper for employee assignment authority

### Inventory

- [ ] Build centralized stock semantics helper
- [ ] Replace ad hoc quant math across modules
- [ ] Revalidate stock on transfer update
- [ ] Validate lot-level availability on create/update
- [ ] Document and test backorder policy

### Testing

- [ ] Add auth security tests
- [ ] Add endpoint permission tests
- [ ] Add territory-scope tests
- [ ] Add tracked stock and transfer regression tests
- [ ] Add concurrency tests for lot claims

### Operations

- [ ] Add config-health preflight checks
- [ ] Add security and stock audit logs
- [ ] Add API monitoring and alerting
- [ ] Define release gate and rollback checklist

## 9. Final Recommendation

This backend should not be labeled production-ready until the security and scope issues are fixed. The good news is that it does not need a rewrite. The system already has the right building blocks:

- access-key gating
- mobile policy helpers
- modular business services
- shared transfer logic
- central exception boundary

The problem is not absence of architecture. The problem is incomplete enforcement.

If the team executes the remediation in the order above, the backend can realistically reach `8+/10` and be defensible for production use.
