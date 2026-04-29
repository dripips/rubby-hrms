# Создаёт ОДНУ реалистичную вакансию + ОДНОГО кандидата с детальным резюме,
# чтобы AI-фичи (разбор резюме / рекомендация / вопросы) имели на чём работать.
# Запуск: bundle exec rails runner "load 'db/seeds/realistic_demo.rb'"

require "prawn"

company = Company.kept.first
hr      = User.find_by(email: "hr@hrms.local")
admin   = User.find_by(email: "admin@hrms.local")
manager = User.find_by(email: "manager@hrms.local")

# ── 1. Вакансия ──────────────────────────────────────────────────────────────
opening = JobOpening.find_or_initialize_by(company: company, code: "JOB-DEMO-001")
opening.assign_attributes(
  title:           "Senior Ruby on Rails Engineer",
  department:      Department.find_by(company: company, code: "ENG_BACK"),
  position:        Position.find_by(company: company, code: "DEV_BACK"),
  grade:           Grade.find_by(company: company, level: 4),
  owner:           hr,
  openings_count:  1,
  state:           :open,
  description:     <<~DESC,
    Ищем сильного Senior Backend-инженера в команду платформы HRMS.
    Команда — 6 backend, 3 frontend, 1 PM, 1 designer. Скейлим систему с
    нескольких компаний-клиентов до тысяч.

    Что предстоит делать:
    • Проектировать и развивать ядро multi-tenant SaaS (Rails 8 + PostgreSQL).
    • Работать со сложными доменами: HR-процессы, payroll, ATS, scheduling.
    • Строить интеграции с внешними системами (HH.ru, LinkedIn, OpenAI).
    • Менторить middle-инженеров, проводить code review, вести RFC-процесс.
    • Owning перформанса: индексы, query plans, N+1, фоновая обработка.
  DESC
  requirements:    <<~REQ,
    Обязательно:
    • 5+ лет коммерческой разработки на Ruby on Rails
    • Глубокое понимание PostgreSQL: индексы, EXPLAIN, миграции без даунтайма
    • Sidekiq / Solid Queue / ActiveJob — фоновые задачи в production
    • RSpec + системные тесты, привычка писать тесты до и после
    • Опыт с Hotwire (Turbo Streams / Frames) или другим SPA-стеком
    • Английский B1+ (документация, общение в issue trackers)
  REQ
  nice_to_have:    <<~NICE,
    Будет плюсом:
    • Open-source контрибуции в Rails-экосистему
    • Опыт с Kafka / Redis Streams для event-driven архитектуры
    • Kubernetes / Helm / GitOps
    • Ведение техблога, выступления на митапах (RubyRussia, Rails Russia)
    • Опыт menторинга и проведения собеседований
    • GraphQL (graphql-ruby) или gRPC
  NICE
  salary_from:     350_000,
  salary_to:       500_000,
  currency:        "RUB",
  employment_type: "full_time",
  published_at:    7.days.ago.to_date
)
opening.save!
puts "✓ JobOpening: #{opening.code} · #{opening.title}"

# ── 2. Кандидат ──────────────────────────────────────────────────────────────
applicant = JobApplicant.find_or_initialize_by(company: company, email: "dmitry.ivanov.dev@example.com")
applicant.assign_attributes(
  job_opening:         opening,
  owner:               hr,
  first_name:          "Дмитрий",
  last_name:           "Иванов",
  phone:               "+7 (905) 123-45-67",
  location:            "Москва",
  current_company:     "Avito",
  current_position:    "Senior Backend Developer",
  years_of_experience: 7,
  expected_salary:     420_000,
  currency:            "RUB",
  portfolio_url:       "https://dmitry-ivanov.dev",
  linkedin_url:        "https://linkedin.com/in/dmitry-ivanov-dev",
  github_url:          "https://github.com/dmitry-ivanov-dev",
  telegram:            "@dmi_dev",
  source:              "linkedin",
  summary:             <<~SUM,
    Senior Backend-инженер с 7 годами на Ruby on Rails. Последние 3 года
    в Avito — отвечал за платёжный сервис (Rails 7, PostgreSQL, Kafka,
    100K RPS пиковой нагрузки), перевёл монолит на event-driven архитектуру,
    снизил latency p99 с 800ms до 120ms. До этого 2 года в Тинькофф (Rails-микросервисы
    для anti-fraud), и 2 года в Яндексе (Internal-tools).

    Активный open-source контрибутор: автор гема pg_search_extended (450⭐),
    регулярные PR в Rails и rspec-rails. Спикер RubyRussia 2025 ("Postgres
    indexes that nobody told you about"), организатор московского Rails-митапа.

    Менторил 4 middle-инженеров до senior-уровня, провожу 6+ интервью в месяц.
    Знаю как строить процессы, code-review культуру и техническое roadmap'ы.
  SUM
  stage:               "interview",
  applied_at:          12.days.ago,
  stage_changed_at:    3.days.ago,
  source_meta:         { avatar_url: "https://i.pravatar.cc/300?u=dmitry-ivanov-real" }
)
applicant.save!

# Резюме PDF — детальный, с реальными разделами
font_path  = Rails.root.join("vendor/fonts/Arial.ttf")
font_bold  = Rails.root.join("vendor/fonts/Arial-Bold.ttf")
pdf_data   = Prawn::Document.new(page_size: "A4", margin: 48) do |pdf|
  if font_path.exist?
    pdf.font_families.update("Arial" => { normal: font_path.to_s, bold: font_bold.to_s })
    pdf.font "Arial"
  end

  # Header
  pdf.fill_color "1d1d1f"
  pdf.font_size(28) { pdf.text "Дмитрий Иванов", style: :bold }
  pdf.fill_color "6e6e73"
  pdf.font_size(13) { pdf.text "Senior Backend Engineer · Ruby on Rails · 7 лет" }
  pdf.fill_color "1d1d1f"
  pdf.move_down 18
  pdf.stroke_color "d2d2d7"
  pdf.stroke_horizontal_rule
  pdf.move_down 14

  # Contacts
  pdf.font_size(10) do
    pdf.fill_color "6e6e73"; pdf.text "CONTACTS", style: :bold; pdf.fill_color "1d1d1f"
    pdf.move_down 4
    pdf.text "Email:    dmitry.ivanov.dev@example.com"
    pdf.text "Phone:    +7 (905) 123-45-67"
    pdf.text "Location: Москва"
    pdf.text "GitHub:   github.com/dmitry-ivanov-dev"
    pdf.text "LinkedIn: linkedin.com/in/dmitry-ivanov-dev"
    pdf.text "Site:     dmitry-ivanov.dev"
  end
  pdf.move_down 18; pdf.stroke_horizontal_rule; pdf.move_down 14

  # Summary
  pdf.font_size(10) do
    pdf.fill_color "6e6e73"; pdf.text "SUMMARY", style: :bold; pdf.fill_color "1d1d1f"
    pdf.move_down 4
    pdf.text applicant.summary, leading: 3
  end
  pdf.move_down 18; pdf.stroke_horizontal_rule; pdf.move_down 14

  # Experience
  pdf.font_size(10) do
    pdf.fill_color "6e6e73"; pdf.text "EXPERIENCE", style: :bold; pdf.fill_color "1d1d1f"
    pdf.move_down 6

    pdf.text "<b>Senior Backend Developer · Avito</b> (2023 — настоящее время)", inline_format: true
    pdf.text "Москва, Россия · Ruby on Rails, PostgreSQL, Kafka, Redis, k8s"
    pdf.move_down 4
    pdf.text "• Архитектор и tech lead платёжного домена (15+ микросервисов, 100K RPS пик)"
    pdf.text "• Перевёл legacy-монолит на event-driven через Kafka, latency p99: 800ms → 120ms"
    pdf.text "• Внедрил contract-testing (Pact) между сервисами, снизил production-incidents в 4×"
    pdf.text "• Менторил 4 middle-инженеров до senior, проектировал growth roadmap"
    pdf.text "• Code-review лид: ~30 PR в неделю, ввёл RFC-процесс для архитектурных изменений"
    pdf.move_down 10

    pdf.text "<b>Backend Developer · Тинькофф</b> (2021 — 2023)", inline_format: true
    pdf.text "Москва, Россия · Ruby on Rails, PostgreSQL, Sidekiq, gRPC"
    pdf.move_down 4
    pdf.text "• Anti-fraud сервис: real-time scoring транзакций, 50K RPS"
    pdf.text "• Оптимизация PostgreSQL: внедрил partial indexes, ускорил queries в 12×"
    pdf.text "• Перевод тестов с MiniTest на RSpec для команды из 8 человек"
    pdf.move_down 10

    pdf.text "<b>Junior Backend Developer · Яндекс</b> (2019 — 2021)", inline_format: true
    pdf.text "Москва, Россия · Ruby on Rails, PostgreSQL"
    pdf.move_down 4
    pdf.text "• Internal-tools для команд продактов (Rails admin-panels, jbuilder API)"
    pdf.text "• Закрыл 80+ тикетов в первый год, получил повышение до middle через 14 месяцев"
  end
  pdf.move_down 18; pdf.stroke_horizontal_rule; pdf.move_down 14

  # Tech stack
  pdf.font_size(10) do
    pdf.fill_color "6e6e73"; pdf.text "TECH STACK", style: :bold; pdf.fill_color "1d1d1f"
    pdf.move_down 4
    pdf.text "• Languages: Ruby (expert), Python (mid), Go (junior)"
    pdf.text "• Frameworks: Rails 7+ (production), Hotwire, Sidekiq, Solid Queue, gRPC, GraphQL"
    pdf.text "• Databases: PostgreSQL (advanced — query plans, indexes, partitioning), Redis"
    pdf.text "• Infra: Docker, Kubernetes, Helm, Terraform, GitOps (ArgoCD)"
    pdf.text "• Testing: RSpec, Capybara, Pact (contract tests), Mutant"
    pdf.text "• Monitoring: Datadog, Prometheus, Sentry, OpenTelemetry"
  end
  pdf.move_down 18; pdf.stroke_horizontal_rule; pdf.move_down 14

  # Open source / talks
  pdf.font_size(10) do
    pdf.fill_color "6e6e73"; pdf.text "OPEN SOURCE & TALKS", style: :bold; pdf.fill_color "1d1d1f"
    pdf.move_down 4
    pdf.text "• Author: pg_search_extended gem (450⭐ on GitHub)"
    pdf.text "• Contributor: rails/rails (3 merged PRs), rspec-rails (5 merged PRs)"
    pdf.text "• Speaker: RubyRussia 2025 — \"Postgres indexes that nobody told you about\""
    pdf.text "• Co-organizer: Moscow Rails Meetup (~120 attendees, monthly)"
  end
end.render

applicant.resume.attach(
  io:           StringIO.new(pdf_data),
  filename:     "resume_dmitry_ivanov.pdf",
  content_type: "application/pdf"
)
puts "✓ JobApplicant: #{applicant.full_name} · #{applicant.email} · resume #{(pdf_data.bytesize / 1024.0).round(1)} KB"

# ── 3. Завершённый HR-раунд со scorecard ─────────────────────────────────────
recruiter_pool = User.kept.where(role: %i[hr superadmin manager]).to_a

hr_round = applicant.interview_rounds.find_or_initialize_by(kind: "hr")
hr_round.assign_attributes(
  state:             "completed",
  scheduled_at:      6.days.ago,
  duration_minutes:  60,
  interviewer:       hr,
  created_by:        hr,
  location:          "Google Meet",
  meeting_url:       "https://meet.google.com/abc-defg-hij",
  competency_scores: { "communication" => 5, "motivation" => 5, "culture_fit" => 4, "reliability" => 5 },
  recommendation:    "strong_yes",
  notes:             <<~NOTE,
    Кандидат отлично проявил себя на HR-раунде. Очень структурированно
    рассказывает про опыт, понятен карьерный путь, мотивация осознанная —
    хочет развиваться в platform-архитектуру. Зрелое отношение к процессам:
    code-review, менторингу, RFC.

    Соответствие нашим ценностям: высокое. Готов к ownership, ведёт open-source.
    Договорились про офер 420k если пройдёт technical раунд.
  NOTE
  decision_comment:  "Сильный senior с правильными soft skills. На tech-раунд однозначно идём.",
  started_at:        6.days.ago,
  completed_at:      6.days.ago + 1.hour
)
hr_round.overall_score = hr_round.calculate_overall_score
hr_round.save!
puts "✓ HR round completed · score=#{hr_round.overall_score} · #{hr_round.recommendation}"

# ── 4. Запланированный tech-раунд ────────────────────────────────────────────
tech_round = applicant.interview_rounds.find_or_initialize_by(kind: "tech")
tech_round.assign_attributes(
  state:             "scheduled",
  scheduled_at:      2.days.from_now.beginning_of_hour + 11.hours, # 13:00
  duration_minutes:  90,
  interviewer:       admin,
  created_by:        hr,
  location:          "Офис Москва, переговорка #5",
  meeting_url:       "https://meet.google.com/xyz-abc-jkl",
  competency_scores: {}
)
tech_round.save!
puts "✓ Tech round scheduled for #{tech_round.scheduled_at.strftime('%d.%m.%Y %H:%M')}"

# ── 5. История переходов ─────────────────────────────────────────────────────
ApplicationStageChange.where(job_applicant: applicant).delete_all
[
  ["applied",   "screening", 9.days.ago,  "Резюме сильное, переводим на скрининг"],
  ["screening", "interview", 6.days.ago,  "HR-раунд прошёл с strong_yes — назначаем технический"]
].each do |from, to, at, comment|
  ApplicationStageChange.create!(
    job_applicant: applicant, user: hr, from_stage: from, to_stage: to,
    comment: comment, changed_at: at
  )
end
puts "✓ 2 stage changes added"

puts ""
puts "═" * 70
puts "ГОТОВО"
puts "═" * 70
puts "Открой профиль: /job_applicants/#{applicant.id}"
puts "Вкладка «AI» → «Запустить» на «Разбор резюме» и «Рекомендация»"
puts "Запланированный tech-раунд → «AI: вопросы для раунда»"
