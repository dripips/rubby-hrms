# HRMS — Human Resources Management System

[English](README.md) | [Русский](README.ru.md)

A modern, opinionated HRMS built on Rails 8 with Apple-HIG design language and 22 AI agents covering the full employee lifecycle — from a candidate's resume to their last day.

This is the first project in the [`rubby`](https://github.com/dripips?tab=repositories&q=rubby) learning umbrella — five progressively serious Ruby/Rails projects exploring real-world domains, not toy apps.

## Highlights

- **Full employee lifecycle:** recruitment → onboarding → KPI → leaves → offboarding
- **22 AI agents** powered by OpenAI: resume analysis, candidate ranking, mentor matching, burnout detection, exit risk scoring, knowledge transfer planning, and more
- **Live UI** — every action streams via Turbo + ActionCable. No page reloads anywhere.
- **Apple-HIG design system** — shared SCSS submodule [`rubby-design-system`](https://github.com/dripips/rubby-design-system) with system colors, SF Pro typography, spring animations
- **Three locales** — Russian (primary), English, German with automatic fallback chain
- **Multi-company ready** — companies → departments → employees, even though only one is seeded by default
- **Audit log** with paper_trail + revert capability for any tracked event
- **Pundit RBAC** with four roles (superadmin / hr / manager / employee)

## Stack

- **Rails 8.1** + Hotwire (Turbo, Stimulus) + Bootstrap 5.3 (overridden by Apple design tokens)
- **PostgreSQL 18** + Solid Queue (jobs) + Solid Cable (WebSocket)
- **Devise** for auth, **Pundit** for authorization
- **paper_trail** + **Discard** for soft-delete and history
- **AASM** for state machines (leaves, interviews, processes)
- **noticed** for in-app notifications + email
- **OpenAI Chat Completions** for AI agents (configurable per task)
- **dartsass-rails** + custom design system submodule
- **RSpec** + FactoryBot + Capybara for testing

## Modules

| Module | What it does |
|---|---|
| **Recruitment** | Openings, applicants, kanban pipeline, interview rounds with scorecards, public careers page, calendar, analytics |
| **KPI** | Weekly metric assignments, evaluations, leaderboard, trend dashboard |
| **Leaves** | Configurable approval rules with priority-driven chains, balance tracking, burnout analytics |
| **Onboarding / Offboarding** | Process templates with milestone-grouped tasks, AI-augmented plans, exit risk assessment |
| **Audit log** | Every change tracked, revertable, filterable by user / event / model / period |
| **Settings** | Languages, SMTP, AI providers, notifications, careers page, leaves rules, genders dictionary, process templates |

## AI agents

All 22 agents go through a unified pipeline: `RunAiTaskJob` (async) → `RecruitmentAi` service → `AiRun` record → live broadcast to UI.

**Recruitment side:**
- `analyze_resume` — extract skills, experience, strengths, red flags
- `recommend` — hiring recommendation (strong_yes / yes / maybe / no / strong_no) + score
- `generate_assignment` — tailored test assignment matching candidate level
- `questions_for` — interview round questions targeted to candidate profile
- `summarize_interview` — round summary with verdict
- `compare_candidates` — rank multiple candidates for one role
- `offer_letter` — full offer letter with negotiation notes

**Employee retention:**
- `burnout_brief` — burnout risk analysis from KPI + leaves + tenure
- `suggest_leave_window` — optimal leave window suggestion
- `kpi_brief` — performance brief for managers
- `meeting_agenda` — 1:1 meeting prep
- `kpi_team_brief` — strategic team performance overview
- `compensation_review` — fair-comp assessment with raise / hold / review_band verdict
- `exit_risk_brief` — proactive 0–100 exit risk score with retention actions

**Onboarding:**
- `onboarding_plan` — personalized task plan augmenting the template
- `welcome_letter` — warm welcome email
- `mentor_match` — top-3 mentor candidates with fit reasoning
- `probation_review` — probation review brief

**Offboarding:**
- `knowledge_transfer_plan` — KT areas, recipients, session structure
- `exit_interview_brief` — personalized exit interview questions
- `replacement_brief` — job opening draft for the replacement

A server-side **AiLock** prevents duplicate runs on the same subject across browser tabs and sessions, with automatic UI rollback when the worker finishes.

## Quickstart

Prerequisites: **Ruby 4.0.3**, **PostgreSQL 18**, **Bundler 4.0.6**.

```bash
# Clone with the design-system submodule
git clone --recurse-submodules git@github.com:dripips/rubby-hrms.git
cd rubby-hrms

# Install dependencies
bundle install

# Configure database
bin/rails db:create db:migrate db:seed

# Run dev server (Rails + dartsass watcher + Solid Queue)
bin/dev
```

Default seeded users (password: `password123`):
- `admin@hrms.local` — superadmin
- `hr@hrms.local` — HR specialist
- `manager@hrms.local` — manager
- `alice@hrms.local` — regular employee

The seed creates a realistic team of 27 employees with hierarchy, KPI history, leave records, active recruitment pipelines, and 7 onboarding/offboarding processes in different stages.

## Configuration

AI providers, models, and per-task token limits are configurable through **Settings → AI Assistant** (HR/superadmin only). The OpenAI API key is stored encrypted in `app_settings`.

## Architecture notes

- **Live UI**: every controller action broadcasts via `Turbo::StreamsChannel`. No `redirect_to` after AJAX — all updates are turbo-streams.
- **i18n**: Russian is primary; en/de fall back to ru via `config.i18n.fallbacks = { en: [:ru], de: [:ru] }`. Translations are added one locale at a time.
- **Cyrillic paths break things on Windows.** The project lives at `C:\rubby\01_hrms\` — moving it under a Cyrillic directory caused Bootsnap, file I/O, and SSH known_hosts failures.

## License

MIT

## Author

[Vadim Bobkov](https://github.com/dripips) — building this as part of a Ruby learning journey while shipping production code in PHP, Java, Python, and TypeScript elsewhere.
