# Changelog

All notable changes to this project are documented here. Format inspired by [Keep a Changelog](https://keepachangelog.com/), versioning follows [SemVer](https://semver.org/).

Full release notes (with longer prose) live on GitHub Releases: https://github.com/dripips/rubby-hrms/releases

---

## [Unreleased]

Working on:
- Multi-tenant subdomain routing (`acme.hrms.local` → tenant) — v2.0
- RSpec coverage push to >80%
- Performance instrumentation (bullet, rack-mini-profiler)

See [ROADMAP.md](ROADMAP.md) for the full backlog.

---

## [1.8] — 2026-05-12

### Added
- **Smoke spec** (`spec/requests/smoke_spec.rb`) — 38 GET-probes across every major page, auto-runs in CI. Catches runtime `ActionView::Template::Error` before merge.
- **Zeitwerk autoload check** in CI — catches class-name / filename mismatches at boot.
- **`.ics` calendar export** for recruitment interviews. `GET /recruitment/calendar.ics` (button in page header), subscribable in Google / Outlook / Apple Calendar. RFC 5545 compliant via own `IcalendarBuilder` (no extra gem).

### Fixed
- `db/seeds.rb` was broken on a fresh database — users were created **after** sub-seeds that depend on them. Moved user creation before `employees.rb`.
- Two stale view bugs caught by smoke spec: `a.target_value` → `a.target` on KpiAssignment, `@employee.gender_ref` → `@employee.gender_record`.

### i18n
- 2318 / 2318 / 2318 keys (ru / en / de)

## [1.7] — 2026-05-12

### Added
- **One-click Telegram linking via webhook.** Profile → "Open Telegram" button → bot opens → Start → done. Backend generates a one-time link token (10 min TTL), Telegram webhook validates `X-Telegram-Bot-Api-Secret-Token` and binds chat_id automatically.
- Manual fallback (paste chat_id via `@userinfobot`) retained when webhook isn't registered.
- `/settings/communications` — "Register webhook" button calls `setWebhook` with a generated secret. Three states UI: active / not configured / re-register / remove.
- Webhook reply pattern: bot replies "✓ Done, linked to email@…" on successful binding.

### Security
- `tg_link_token`: 16-byte URL-safe random, single-use, 10-minute TTL.
- Webhook endpoint uses `secure_compare` on the secret header; `skip_before_action :verify_authenticity_token` + `protect_from_forgery with: :null_session`.
- localhost registration blocked with helpful message (Telegram requires HTTPS public URL).

## [1.6] — 2026-05-12

### Added
- **Slack + Telegram channels** for Noticed v3 notifiers.
  - `app/notifiers/delivery_methods/{slack,telegram}.rb` — custom HTTP-POST delivery methods.
  - `ApplicationNotifier` adds `deliver_by :slack/:telegram` with `if:` gated through `User#notify_for?(event_kind, channel)`.
  - `User::NOTIFICATION_CHANNELS = [in_app, email, slack, telegram]`.
- **/profile/integrations** tab — Slack incoming webhook + Telegram chat_id with real test buttons.
- **/profile/notifications** — extra columns for Slack / Telegram (disabled until connected, with "connect" hotlink).
- **/settings/communications** — global Bot Token (per-company AppSetting) with "Verify connection" via `getMe` (auto-fetches bot @username).
- Step-by-step inline instructions for both channels (no more "ask HR/IT").

### Migration
- `users.slack_webhook_url`, `users.telegram_chat_id`

## [1.5] — 2026-05-12

### Added
- **Mobile responsiveness pass** — focused SCSS for <768px and <576px.
  - `.table-apple` → block + `overflow-x: auto`
  - Kanban cards 86vw on mobile
  - `.card-apple` padding scales down
  - Tabulator compact mode
  - `.page-header__actions` full-width on mobile
  - Filter chips vertical stack on small screens
  - Section tabs horizontal scroll
  - Auth shell hero hidden < 576px
  - `@media (hover: none)` — disables sticky hover on touch

### Fixed
- CI failure: bumped `nokogiri` 1.19.2 → 1.19.3 (CVE-2024-... GHSA-c4rq + GHSA-v2fc).

## [1.4] — 2026-05-12

### Added
- **iOS Springboard-style dashboard.**
  - CSS Grid 4 cols / 2 cols / 1 col responsive
  - Three widget sizes: S (1 col) / M (2 cols) / L (4 cols / full row)
  - Live edit mode on /dashboard — drag-and-drop reorder, floating size pips, eye toggle (hide/show), sticky save/cancel bar
  - Dropping reorder logic uses `elementsFromPoint` + `is-drop-target` highlight; insertBefore happens only on drop (no live DOM mutation during drag — fixed "twitching" issue)
  - DEFAULT_SIZES per widget (KPI tiles / Recent Activity / Documents Expiring = L; rest = M)
  - `users.dashboard_preferences.sizes` persists per-user

### Fixed
- `_my_kpi.html.erb`: `a.target_value` → `a.target` (column doesn't exist; method renamed during initial migration).
- Dashboard customize: removed stale `pulse` animation from edit-mode (was breaking Chrome's drag state machine on grid items).

## [1.3] — 2026-05-01

### Added
- **2FA (RFC 6238 TOTP) + backup codes.**
  - QR-code setup via `rqrcode`, verify-step before enable.
  - Drift ±30s + anti-replay via `otp_last_used_at`.
  - 10 backup codes, single-use, bcrypt-hashed JSON array.
  - `/profile/two_factor` (setup/manage/regenerate/disable) + `/two_factor/challenge` (sign-in second step with 5-min pending TTL).
  - `Users::SessionsController` intercepts 2FA users after password auth, redirects to challenge.
- Profile/security card with 2FA enable button + status pill.

### Migration
- `users.otp_secret`, `otp_required_for_login`, `otp_backup_codes`, `otp_enabled_at`, `otp_last_used_at`

## [1.2] — 2026-05-01

### Added
- **Production hardening.**
  - `config/environments/production.rb`: `force_ssl` + secure cookies (toggle via `DISABLE_SSL=true`, `/up` excluded from SSL-redirect).
  - Random seed passwords in prod (`SecureRandom.alphanumeric(20)`).
- **`AiBudgetGuard`** — hard-cap on AI cost: blocks `RunAiTaskJob` when month spend ≥ `HARD_CAP_MULTIPLIER × monthly_budget_usd` (default 2.0×). Cached 60s.
- **GDPR / 152-FZ compliance** at `/profile/privacy`:
  - `GdprExporter` → JSON DSAR (10 sections: account, profile, employment, documents, leaves, KPI, interviews, notifications, AI runs, audit log) — Article 15
  - `GdprDeleter` → PII anonymization, audit trail retained with author → "deleted-user-N" — Article 17
- **`HrmsErrorSubscriber`** — centralized Rails.error subscriber writing to `log/errors.log` (rotation 5×10MB), optional Sentry forwarding.
- **Backup / restore scripts**: `scripts/backup.sh` (pg_dump + tar storage, ratates via `HRMS_BACKUP_RETAIN`) + `scripts/restore.sh` (with YES-confirmation).

## [1.1] — 2026-05-01

### Added
- **Configurable dashboard** with 10 widgets (KPI tiles, Recent Activity, Upcoming Events, My KPI, Pending Leaves, Documents Expiring, Burnout Alerts, AI Activity, Onboarding, Offboarding). Drag-drop reorder + role-based visibility.
- **Users admin** (`/settings/users`) — superadmin/HR full CRUD, lock/unlock (Devise + discard), reset password (Devise reset-link).
- **Profile tabs**: Personal / Security / Notifications.

### Fixed
- Rubocop: removed double-space in routes.
- Brakeman: removed `:role` mass-assignment privilege escalation in `settings/users` (whitelist check).

## [1.0] — 2026-05-01

### Added
- First public release: Universal HRMS for any industry.
- Rails 8.1 + Hotwire + PostgreSQL 18 + SolidQueue + SolidCable.
- Devise auth + Pundit RBAC + PaperTrail audit + Discard soft-delete + AASM state machines.
- 24 AI agents across recruitment / employee retention / onboarding / offboarding / documents / dictionaries.
- Multi-provider AI (OpenAI / OpenRouter / Together / Groq / DeepSeek / Anthropic / Custom vLLM/Ollama).
- Custom Fields system via Dictionaries (`kind: field_schema`) — bend any entity to any industry.
- Documents subsystem: pdf-reader + Tesseract + OpenAI Vision fallback, expiry notifications.
- Recruitment: openings → applicants → kanban → interview rounds → analytics → calendar.
- KPI: weekly assignments + evaluations + leaderboard + trend.
- Three locales (RU / EN / DE) with 2050+ i18n keys.
- One-command Docker install (`scripts/install.sh`).

[Unreleased]: https://github.com/dripips/rubby-hrms/compare/v1.8...master
[1.8]: https://github.com/dripips/rubby-hrms/releases/tag/v1.8
[1.7]: https://github.com/dripips/rubby-hrms/releases/tag/v1.7
[1.6]: https://github.com/dripips/rubby-hrms/releases/tag/v1.6
[1.5]: https://github.com/dripips/rubby-hrms/releases/tag/v1.5
[1.4]: https://github.com/dripips/rubby-hrms/releases/tag/v1.4
[1.3]: https://github.com/dripips/rubby-hrms/releases/tag/v1.3
[1.2]: https://github.com/dripips/rubby-hrms/releases/tag/v1.2
[1.1]: https://github.com/dripips/rubby-hrms/releases/tag/v1.1
[1.0]: https://github.com/dripips/rubby-hrms/releases/tag/v1.0
