# Roadmap

Snapshot of what's done and what's planned. Updated per release. For the full release log see [CHANGELOG.md](CHANGELOG.md).

## ✓ Done (v1.0 → v1.8)

| Milestone | Highlights |
|---|---|
| v1.0 — Universal HRMS | Custom fields, 24 AI agents, 3 locales, Docker install |
| v1.1 — Dashboard customization | 10 widgets, role visibility, users admin, profile tabs |
| v1.2 — Production hardening | force_ssl, AiBudgetGuard, GDPR (export+erasure), backups, error tracking |
| v1.3 — 2FA | TOTP (RFC 6238), QR setup, 10 backup codes, sign-in challenge |
| v1.4 — iOS dashboard | S/M/L grid, live edit-mode, drag-drop reorder, size pip control |
| v1.5 — Mobile | Tables → scroll, kanban narrowed, page-header full-width, hover-disable on touch |
| v1.6 — Slack/Telegram | Custom Noticed delivery methods, per-user webhook/chat_id, settings + integrations UI |
| v1.7 — One-click TG linking | Webhook + secret_token, /start payload, manual fallback |
| v1.8 — CI guards + .ics | Smoke spec (38 GETs), Zeitwerk check, .ics export for interviews |

## 🔜 Next up (v1.9 — v1.12)

These are smaller, self-contained improvements that don't break the architecture.

### v1.9 — OSS hygiene + Performance
- [x] **CHANGELOG.md** + **ROADMAP.md** + **CONTRIBUTING.md**
- [ ] **N+1 detection** via `bullet` gem (dev/test groups)
- [ ] **Performance profiler** via `rack-mini-profiler` (dev)
- [ ] **Fragment caching** on hot dashboard widgets (`kpi_tiles`, `recent_activity`)
- [ ] **Brakeman ignore policy** documented in `config/brakeman.ignore.md`

### v1.10 — Quality / coverage
- [ ] **RSpec coverage push to >80%** — focus on risky services
  - `AiBudgetGuard` (cost protection)
  - `GdprExporter` / `GdprDeleter` (compliance)
  - `IcalendarBuilder` (RFC 5545 conformance)
  - `DeliveryMethods::Slack` / `Telegram` (external integration)
  - `TelegramWebhooksController` (security-critical webhook)
- [ ] **API documentation** — OpenAPI 3 spec for `/api/v1/openings/*` + Swagger UI at `/api-docs`
- [ ] **Request specs** for all controllers (currently only smoke spec)

### v1.11 — Polish + small features
- [ ] **OCR pipeline upgrade** — poppler-utils + pdf-images for scan-PDFs (currently fails on photo-scans)
- [ ] **Accessibility audit** — ARIA roles, keyboard nav, focus management
- [ ] **CSP report-only mode** — Content Security Policy in production
- [ ] **Bullet baseline** + fix all flagged N+1 in employee / kanban / dashboard

### v1.12 — Communication & integrations
- [ ] **In-app chat** between HR ↔ employee (ActionCable + persistent threads)
- [ ] **Google Calendar bi-directional sync** for interview rounds (using existing .ics + OAuth)
- [ ] **CalDAV subscribe URL** — auto-update calendar (vs one-shot .ics)
- [ ] **Email reminders** for interview rounds via Noticed scheduled delivery

## 🚀 v2.0 — Multi-tenant & deployment

Bigger architectural shifts. Each can ship independently but together they enable hosted SaaS usage.

### Multi-tenant routing
- [ ] Replace every `Company.kept.first` hardcode with subdomain-resolved tenant (`acme.hrms.local` → tenant)
- [ ] Middleware: `Hrms::TenantResolver` reads subdomain, sets `Current.company`, scopes all queries
- [ ] DB: optional FK validation that all `company_id`-scoped models actually filter by tenant
- [ ] Sign-in flow with tenant slug input on the apex domain
- [ ] Cookie domain handling: parent-domain cookies for SSO across subdomains

### Deployment & ops (per user request 2026-05-13)
- [ ] **Docker container** — Dockerfile + entrypoint that runs `db:migrate` + asset compile on startup
- [ ] **`scripts/install.sh`** rewrite — one-command from-scratch deploy:
  - Pulls latest image
  - Generates `RAILS_MASTER_KEY` + DB password if missing
  - Builds + starts compose stack (`db + app + worker`)
  - Creates first superadmin with generated password (printed to stdout)
  - Self-checks `/up` healthcheck before reporting success
- [ ] **`scripts/update.sh`** — zero-downtime upgrade between minor versions:
  - Pulls new image tag (e.g. `dripips/hrms:v1.10`)
  - Runs migrations against a temp container first
  - Hot-swaps app container (no DB downtime)
  - Rollback path on failure
- [ ] **`docker-compose.prod.yml`** with sensible defaults (volumes, networks, restart policy)
- [ ] **Hosted demo** at `demo.hrms.app` — auto-resets DB nightly via cron, public credentials

### SaaS-ready features
- [ ] Per-tenant settings ownership (one company can't read another's AppSetting)
- [ ] Billing-aware AI cost guard (per-tenant `monthly_budget_usd`)
- [ ] Tenant-scoped audit log (one tenant's revert can't touch another)

## 🌌 v3.0+ — Speculative

Big bets, ordered by interest:

- **AI agent SDK** — public API for third-party AI providers to register as agents (think "OpenAI plugin" but for HRMS lifecycle events)
- **Native mobile** — React Native shell sharing the same i18n + REST API
- **Marketplace for field schemas** — share & download industry-specific schemas (medical, manufacturing, hospitality)
- **Internal "process designer"** — visual workflow builder for approval rules, onboarding flows, KPI templates

---

## Contributing

Pick anything from the v1.9 — v1.12 list and open a PR. For v2.0 items, start with a discussion issue first — they touch the routing/auth core.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution flow.
