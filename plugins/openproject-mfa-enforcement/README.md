# OpenProject MFA Enforcement

Organization-wide **two-factor authentication (2FA) enforcement** for OpenProject.
Administration → **2FA enforcement**.

OpenProject Community Edition already ships per-user TOTP 2FA (the bundled
`two_factor_authentication` module). This plugin does **not** reimplement TOTP — it
adds an **enforcement policy** on top of CE's existing 2FA:

- Require **all users** (or a **selected group**) to configure 2FA.
- A configurable **grace period** before access is blocked.
- A login-time **gate** that redirects non-compliant users to the 2FA setup page
  once their grace expires.

It is original work built only against OpenProject's public plugin API
(`OpenProject::Plugins::ActsAsOpEngine`). It contains, copies, and bypasses **no**
OpenProject Enterprise (EE) source or license check.

## How it works

| Concern              | Where                                                                 |
|----------------------|-----------------------------------------------------------------------|
| Policy (on/off, grace, group, start) | `Setting.plugin_openproject_mfa_enforcement`, wrapped by `MfaEnforcement::Policy` |
| Compliance decision  | `MfaEnforcement::EnforcementChecker` (gates on CE's `User#otp_devices.get_active`) |
| Login-time gate      | `OpenProject::MfaEnforcement::ControllerGate` included into `ApplicationController` via `to_prepare` |
| Gate page            | `MfaEnforcement::EnforcementController#blocked` → `enforcement/blocked.html.erb` |
| Admin UI             | `MfaEnforcement::AdminSettingsController` → `admin_settings/show.html.erb` |
| Audit trail          | `MfaEnforcement::AuditEvent`, table `op_mfa_audit_events`              |

No core files are modified. The gate is installed with the official
`ActiveSupport::Reloader.to_prepare` hook.

## Admin lock-out safety (read this)

Lock-out / redirect-loop is the dominant risk of any enforcement feature. This
plugin has **four independent safeguards**:

1. **The 2FA-setup path is never gated.** CE's entire `two_factor_authentication`
   controller namespace (including the My-account device setup and forced
   registration) is allowlisted, so a blocked user can always reach the page that
   resolves the block.
2. **The admin settings page is never gated.** An admin can always reach
   Administration → 2FA enforcement to switch the policy off — even if the admin's
   own account is non-compliant.
3. **Login / logout are never gated.** The `account`/sessions controllers are
   allowlisted, so the local-password admin login always works (no redirect loop).
4. **Two break-glass escapes**:
   - **ENV kill switch** — set `OPENPROJECT_2FA_ENFORCEMENT_DISABLED=true` and
     restart; enforcement is disabled instance-wide regardless of the DB setting.
   - **Rails console** —
     ```ruby
     Setting.plugin_openproject_mfa_enforcement =
       Setting.plugin_openproject_mfa_enforcement.merge("enforced" => false)
     ```

Additionally the gate **fails open**: any unexpected error in the gate (or in the
CE 2FA lookup) is logged and the request proceeds, so a bug can never lock anyone
out.

## Scope of enforcement (security)

- Only **browser GET / HTML, non-XHR** requests are gated. **API / token / JSON**
  requests pass through, so automation is not broken. (Per the plan: enforce on
  interactive browser sessions; do not silently block API tokens.) Tighten this in
  `ControllerGate#op_mfa_gateable_request?` if you want stricter API handling.
- Enabling/disabling/updating the policy is **audit-logged** to
  `op_mfa_audit_events` and to the application log.
- CE's TOTP implementation is **never weakened** — this plugin only gates on its
  result.

## Settings

Administration → **2FA enforcement**:

- **Require two-factor authentication** (toggle). Enabling stamps
  `policy_start_at = now`, which starts the grace countdown for every targeted
  user.
- **Grace period (days)** — `0` enforces immediately.
- **Apply to** — *All users* or a single group.
- A **compliance summary** (users with vs without active 2FA).

## Version-dependent integration points (verify against the running 17-slim image)

- **CE 2FA association** — `User#otp_devices` with the `get_active` scope
  (`TwoFactorAuthentication::Device`). Confirm:
  ```
  docker run --rm openproject/openproject:17-slim \
    grep -rn "def get_active\|has_many :otp_devices" /app
  ```
  Adjust `EnforcementChecker#user_has_2fa?` only if the names differ. (It fails
  open if they do.)
- **2FA setup route** — `my_two_factor_devices_new_path` (and the forced-setup
  `new_forced_2fa_device_path`). Used by `EnforcementController#two_factor_setup_path`
  with a literal fallback.
- **`ApplicationController` + `to_prepare` include** — the shared base controller
  the gate attaches to. Confirm it is still the right base on this image.
- **Admin menu icon** `two-factor-authentication` — swap to `locked` if the icon
  set differs.
- **Rails migration superclass** `ActiveRecord::Migration[7.1]`:
  ```
  docker run --rm openproject/openproject:17-slim \
    cat /app/Gemfile.lock | grep -E '^    rails '
  ```

> Note: CE's bundled 2FA module has its own simple "enforced" flag without grace
> periods or group scoping. This plugin intentionally layers a richer policy on
> top; if you also enable CE's built-in enforcement, decide which one governs to
> avoid double-gating.

## Installation (dev container)

1. Add to `Gemfile.plugins`:
   ```ruby
   gem "openproject-mfa_enforcement", path: "plugins/openproject-mfa-enforcement"
   ```
2. `bundle install`
3. `bundle exec rails db:migrate`
4. Restart the web process; the menu item appears under Administration →
   2FA enforcement.

## Tests

```
bundle exec rspec plugins/openproject-mfa-enforcement/spec
```

- `spec/models/mfa_enforcement/policy_spec.rb` — policy parsing, group scoping,
  grace config, ENV kill switch.
- `spec/services/mfa_enforcement/enforcement_checker_spec.rb` — full
  `must_set_up?` truth table + fail-open behavior.
- `spec/requests/mfa_enforcement/enforcement_spec.rb` — gate redirects after
  grace, admin always reaches settings (no loop), login/setup never gated, group
  scoping.

## License

GPL-3.0-or-later (same family as OpenProject Community Edition).
