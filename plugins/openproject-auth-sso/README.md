# openproject-auth_sso

Enterprise **Single Sign-On (SAML 2.0 / OpenID Connect)** for OpenProject 17,
built as an original AGPL-compatible plugin on top of the standard, fully-free
OmniAuth strategies — **no OpenProject Enterprise source is used**.

It reuses:

- [`omniauth-saml`](https://github.com/omniauth/omniauth-saml) (MIT) — SAML 2.0
- [`omniauth_openid_connect`](https://github.com/omniauth/omniauth_openid_connect) (MIT) — OpenID Connect

Admins configure identity providers in the UI (Administration → **SSO Providers**);
strategies are built at boot from the `op_sso_providers` table.

## Break-glass guarantee (read this first)

This plugin **adds** an SSO login path; it never replaces or disables local-password
login. The local sign-in form at **`/login`** always remains available.

> **Always keep at least one local administrator account.** If an identity
> provider is misconfigured you can still sign in locally. To disable a broken
> provider from the Rails console:
>
> ```ruby
> AuthSso::Provider.update_all(active: false)   # then restart the web process
> ```

## Security

- **Secrets encrypted at rest.** `client_secret` / SP private key are stored in the
  encrypted `secrets` column via Rails 7 `encrypts`. Requires
  `ActiveRecord::Encryption` keys to be configured (OpenProject sets these from its
  secret store — *verify against your running image*). Secrets are never logged and
  never rendered back into the edit form.
- **SAML signatures validated.** `want_assertions_signed` is on; an `idp_cert` (or
  fingerprint) is required so forged/unsigned assertions are rejected.
- **OIDC** verifies the `id_token` (signature/nonce/state are handled by
  `omniauth_openid_connect`); `response_type` is fixed to `code`.
- **No admin auto-grant.** `UserProvisioner` never sets `admin = true`. New SSO
  users receive only the instance default (non-admin) global role.
- **Optional email-domain allowlist** (plugin setting) prevents open
  self-registration via the IdP. Auto-provisioning can be disabled entirely.

## Restart required after config changes

The OmniAuth middleware stack is assembled **once, at boot**. After adding,
editing, activating, or deleting a provider you must **restart the OpenProject web
process**. The admin UI shows a "restart required" banner.

## Installation

1. Add to the repo-level `Gemfile.plugins`:

   ```ruby
   gem "omniauth-saml"
   gem "omniauth_openid_connect"
   gem "openproject-auth_sso", path: "plugins/openproject-auth-sso"
   ```

2. `bundle install`
3. `bundle exec rails db:migrate` (creates `op_sso_providers`)
4. Restart the web process.

## Configuring a provider

Administration → SSO Providers → **Add provider**. Pick SAML or OIDC, fill the IdP
metadata, set **Active**, save, then **restart**. Register the displayed **callback
URL** (`/auth/sso_<id>/callback`) with your IdP.

## Verify against the running 17-slim image

Several integration points are version-dependent and are flagged in the source
with `VERIFY against the running 17-slim image` comments:

- The "login required" filter name (`check_if_login_required`).
- The session-login helper (`login_user!` / `successful_authentication`).
- User lookup/creation API (`User.find_by(mail:)`, `activate`, required fields).
- Whether core already claims `/auth/:provider/callback` and `/auth/failure`.
- `ActiveRecord::Encryption` keys present for `encrypts`.

### Alternative wiring (if core OmniAuth conflicts)

OpenProject ships its own integration via
`OpenProject::Plugins::AuthPlugin#register_auth_providers` +
`OmniAuthLoginController`. If core's `/auth/:provider` middleware shadows this
plugin's self-contained `OmniAuth::Builder`, switch the engine to
`register_auth_providers` (which routes callbacks through core's
`Authentication::OmniauthService`) and drop `SessionsController` + the callback
route. The DB model, admin UI, and option builders are reusable unchanged.

## Testing

```bash
bundle exec rspec plugins/openproject-auth-sso/spec
```

Specs cover the model (validation, secret encryption, option builders), the
`UserProvisioner` (create/reuse, attribute mapping, **never admin**, missing-email
and allowlist rejection), and the callback request flow (OmniAuth `test_mode`).

## License

GPL-3.0-or-later (AGPLv3-compatible). Original work.
