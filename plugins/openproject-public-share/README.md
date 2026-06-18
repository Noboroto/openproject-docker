# openproject-public_share

Tokenized public read-only links for OpenProject CE work packages.

## What it does

Generates a shareable URL (`/share/:token`) that lets unauthenticated users view a work package in a minimal read-only view. No login required — access is gated by the 256-bit token only.

## Security design

| Property | Implementation |
|---|---|
| Token strength | 32-byte `urlsafe_base64` (256 bits) |
| Storage | SHA-256 digest only — raw token shown once |
| Bad token response | Always 404 (no 401/403 — no existence oracle) |
| Expiry | Configurable TTL (default 7 days) |
| Revocation | Immediate on revoke; kill-switch setting revokes all instantly |
| Data exposure | Strict allowlist (id, subject, status, type, done_ratio, updated_at only) |
| Rate limiting | Rack::Attack: 60 req/min per IP on `/share/` |
| Auth path | `ActionController::Base` (not `ApplicationController`) — completely outside OP auth stack |

## Feature flag

Disabled by default. Enable via Administration → Plugins → Public Share → `enabled: true`.

## Kill-switch

Set `kill_switch: true` in plugin settings to instantly invalidate all tokens without deleting DB records.

## Known limitations

- Only work package sharing implemented (query sharing is schema-ready but UI not wired).
- Rich text description, attachments, custom fields are intentionally excluded from the public projection.
