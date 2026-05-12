# Contributing

Thanks for your interest! This guide covers how to get the project running locally, what to look at first, and how to land a PR that gets merged quickly.

## TL;DR

```bash
git clone --recurse-submodules https://github.com/dripips/rubby-hrms.git
cd rubby-hrms
bundle install
bin/rails db:setup db:seed
bin/rails dartsass:build
bin/dev      # or: bin/rails s
```

Then open http://localhost:3000 and log in as `admin@hrms.local` / `password123`.

## Project layout

| Path | What lives there |
|---|---|
| `app/controllers` | Standard Rails controllers + Devise overrides |
| `app/models` | AR models + AASM state machines + Discard soft-delete |
| `app/services` | Plain Ruby services (AiBudgetGuard, GdprExporter, IcalendarBuilder, MessageDispatcher, DashboardWidgets, …) |
| `app/notifiers` | Noticed v3 event classes + custom `DeliveryMethods` (Slack, Telegram) |
| `app/policies` | Pundit policies — one per resource |
| `app/javascript/controllers` | Stimulus controllers (no SPA framework) |
| `vendor/design-system/` | Submodule with Apple-HIG SCSS tokens shared across 5 sibling projects |
| `config/locales/*.yml` | i18n — keep ru/en/de **in parity** (same key set) |
| `db/seeds/*.rb` | Idempotent dev seed in pieces |
| `spec/` | RSpec — request specs first, model specs as needed |

## Conventions

- **Smoke test must pass.** New views/routes need to be added to `spec/requests/smoke_spec.rb` so CI catches `ActionView::Template::Error` before merge.
- **i18n parity.** When you add a key to `ru.yml`, add it to `en.yml` and `de.yml` too. Run `bin/rails runner 'puts I18n.t("your.key")'` per locale to sanity-check.
- **No magic constants.** Use I18n + `User::NOTIFICATION_KINDS`-style class constants instead.
- **Don't add UI without state.** New views should render with empty/zero data — `smoke_spec` proves this on every PR.
- **Apple design system.** Reach for `card-apple`, `btn-primary`, `pill`, `list-apple__item` first; only add new SCSS in `vendor/design-system/` (separate submodule PR).
- **Keep `master` green.** All four CI checks (Brakeman, Bundler-audit, Rubocop, RSpec+smoke) must pass before merge.
- **One feature per PR.** Don't bundle a bug fix with a new feature — separate commits / PRs make review faster.
- **No `--no-verify` / `--amend` of pushed commits.** Create a follow-up commit instead.

## Running the test suite

```bash
bin/rails db:test:prepare
bundle exec rspec
```

The smoke spec is the heaviest (loads full seed). Run it explicitly if you only changed views:

```bash
bundle exec rspec spec/requests/smoke_spec.rb
```

Lint + security:

```bash
bin/rubocop -a      # autocorrect
bin/brakeman        # security
bin/bundler-audit   # gem CVEs
```

## Updating screenshots

When you change a key view, regenerate the README screenshots:

```bash
bin/rails s -p 4000   # in one terminal
bin/rails screenshots # in another (auto-logins as admin, takes 1440×900 per locale + dark hero)
```

Specific page only:

```bash
ONLY=01-dashboard,03-recruitment-kanban bin/rails screenshots
LOCALES=en bin/rails screenshots
```

## i18n workflow

Adding a key:

1. Edit your view: `<%= t("scope.new_key", default: "Fallback text") %>`
2. Add to `config/locales/ru.yml`, `en.yml`, `de.yml` (keep alphabetical order within scope)
3. Verify parity:

```bash
bin/rails runner '
%w[ru en en de].uniq.each do |l|
  data = YAML.load_file("config/locales/#{l}.yml")[l]
  flat = ->(h, p="") { h.flat_map { |k,v| v.is_a?(Hash) ? flat.call(v, p+k.to_s+".") : [p+k.to_s] } }
  puts "#{l}: #{flat.call(data).size} keys"
end
'
```

All three locales should show the same number of keys.

## Adding a new AI agent

1. Add to `AiRun::KINDS` array
2. Create `app/services/ai/<your_agent>_service.rb` with `call(record)` method
3. Add `app/views/ai/<scope>/_<your_agent>_form.html.erb`
4. Add i18n keys: `ai.actions.<your_agent>` + `ai.<your_agent>.*`
5. Wire route in `config/routes.rb` under `namespace :ai`
6. Update `app/views/ai_runs/index.html.erb` filter list

## Pull request flow

1. Fork → branch from `master`
2. Make commits with clear messages (imperative mood: "Add X" not "Added X")
3. Run full CI locally:

```bash
bin/rubocop -a && bin/brakeman --no-pager && bin/bundler-audit && bundle exec rspec
```

4. Open PR with:
   - **Summary** (1–3 bullets)
   - **Why** (link to issue or describe the user pain)
   - **Test plan** (manual steps to verify)
   - Screenshot if UI changes
5. Address review comments — push fixup commits (no force-push).

Maintainers respond within a week typically. Keep PRs small (<400 lines diff) for fastest turnaround.

## What to pick if you're new

Easy first PRs (start here):
- Pick an issue tagged `good first issue`
- Add missing i18n parity (run the script above, find the gap, fill it)
- Add a smoke test path that's currently missing
- Improve a screenshot caption in `README.md` / `README.ru.md` / `README.de.md`
- Fix a Rubocop warning (`bin/rubocop -a` and look at what changed)

Medium:
- Pick an item from [ROADMAP.md](ROADMAP.md) under v1.10 / v1.11
- Add a request spec for any controller currently untested

Big (open a discussion first):
- Anything from v2.0 in [ROADMAP.md](ROADMAP.md)

## Code of conduct

Be respectful. Assume good faith. Take heated disagreements offline. We follow the [Contributor Covenant 2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
