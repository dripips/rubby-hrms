# Дополнительный пул из 4 кандидатов на "Senior Ruby on Rails Engineer"
# с разными профилями — чтобы тестировать compare_candidates AI-функцию.
#
# Запуск: bundle exec rails runner "load 'db/seeds/realistic_pool.rb'"

require "prawn"

company = Company.kept.first
hr      = User.find_by(email: "hr@hrms.local")
admin   = User.find_by(email: "admin@hrms.local")
manager = User.find_by(email: "manager@hrms.local")

opening = JobOpening.kept.find_by(company: company, code: "JOB-DEMO-001")
unless opening
  raise "JOB-DEMO-001 не найдена. Сначала прогони: rails runner \"load 'db/seeds/realistic_demo.rb'\""
end

font_path = Rails.root.join("vendor/fonts/Arial.ttf")
font_bold = Rails.root.join("vendor/fonts/Arial-Bold.ttf")

# Хелпер: генерируем простой PDF резюме под профиль
build_resume = ->(applicant, sections) {
  Prawn::Document.new(page_size: "A4", margin: 48) do |pdf|
    if font_path.exist?
      pdf.font_families.update("Arial" => { normal: font_path.to_s, bold: font_bold.to_s })
      pdf.font "Arial"
    end
    pdf.fill_color "1d1d1f"
    pdf.font_size(28) { pdf.text applicant.full_name, style: :bold }
    pdf.fill_color "6e6e73"
    pdf.font_size(13) { pdf.text "#{applicant.current_position} · #{applicant.current_company}" }
    pdf.fill_color "1d1d1f"
    pdf.move_down 14; pdf.stroke_color "d2d2d7"; pdf.stroke_horizontal_rule; pdf.move_down 14
    sections.each do |heading, body|
      pdf.font_size(10) do
        pdf.fill_color "6e6e73"; pdf.text heading.to_s.upcase, style: :bold; pdf.fill_color "1d1d1f"
        pdf.move_down 4; pdf.text body.to_s, leading: 3
      end
      pdf.move_down 14; pdf.stroke_horizontal_rule; pdf.move_down 14
    end
  end.render
}

candidates = [
  # Middle-разработчик с потенциалом, growth-mindset
  {
    first_name: "Алексей", last_name: "Морозов",
    email: "alexey.morozov.dev@example.com",
    phone: "+7 (916) 234-56-78",
    current_company: "Skyeng",
    current_position: "Middle Backend Developer",
    years: 4,
    salary: 280_000,
    location: "Санкт-Петербург",
    source: "hh",
    summary: <<~SUM,
      Middle Backend-разработчик с 4 годами опыта на Ruby on Rails. Последние
      2 года в Skyeng: участвовал в миграции legacy-монолита на event-driven,
      работал с PostgreSQL и Sidekiq. До этого 2 года в Wildberries в команде
      платежей.

      Активно учусь — закончил курс по distributed systems в МФТИ, регулярно
      читаю книги по архитектуре. Пишу в личный блог про PostgreSQL-оптимизацию.
      Хочу расти до senior — нужна команда с сильным менторингом и интересными
      архитектурными вызовами.
    SUM
    sections: {
      "Experience" => "Skyeng (2024-now) · Middle Backend\nWildberries (2022-2024) · Junior→Middle\n\nКлючевые проекты: миграция payment-flow на event-driven, оптимизация heavy queries.",
      "Skills" => "Ruby/Rails (advanced), PostgreSQL (intermediate), Redis, Sidekiq, RSpec.\nЗнаком с: Kafka (на курсе), Docker (использую), gRPC (читал статьи).",
      "Goals" => "Хочу расти до senior. Интересны platform-задачи, distributed systems, менторинг младших."
    },
    stage: "interview",
    rounds: [
      {
        kind: "hr", state: "completed", days_ago: 4,
        scores: { "communication" => 4, "motivation" => 5, "culture_fit" => 5, "reliability" => 4 },
        recommendation: "yes",
        notes: "Очень мотивированный. Видно желание расти. Soft skills хорошие, культурно вписывается. Технический потенциал явно выше текущего уровня — нужно проверить на tech-раунде."
      },
      {
        kind: "tech", state: "scheduled", days_ago: -3, # завтра
        scores: {}, recommendation: nil, notes: nil
      }
    ]
  },

  # Senior с проблемами: job-hopper, stack drift
  {
    first_name: "Михаил", last_name: "Соколов",
    email: "mikhail.sokolov.dev@example.com",
    phone: "+7 (903) 456-78-90",
    current_company: "Self-employed (consulting)",
    current_position: "Senior Engineer (independent)",
    years: 9,
    salary: 480_000,
    location: "Удалённо (Беларусь)",
    source: "linkedin",
    summary: <<~SUM,
      9 лет коммерческого опыта. Последние 3 года фрилансю, до этого менял
      компании каждые ~12 месяцев: Mail.ru (Ruby), Lamoda (Python/Django),
      X5 Retail (Java/Spring), Альфа-банк (Go/gRPC).

      Сильная сторона — могу быстро влиться в любой стек, повидал разные
      архитектуры. Слабая — нет глубокого ownership одной системы. Сейчас
      хочу стабильности и долгосрочного проекта где смогу глубоко погрузиться.

      Личных проектов почти нет, выступлений тоже. Open-source — несколько
      мелких PR в gem'ы по работе.
    SUM
    sections: {
      "Experience" => "Freelance (2023-now) · Backend consulting (mostly Node.js, Python)\nАльфа-банк (2022-2023) · Go/gRPC\nX5 Retail (2021-2022) · Java/Spring\nLamoda (2020-2021) · Python/Django\nMail.ru (2018-2020) · Ruby/Rails",
      "Skills" => "Python (current), Go, Java, Ruby (rusty — последний раз ~3 года назад).\nPostgreSQL, MongoDB, Kafka — на разных уровнях.",
      "Note" => "Готов вернуться к Rails, но придётся обновлять знания — стек ушёл вперёд (Hotwire, Solid Queue, Rails 7+ практик не знаю)."
    },
    stage: "screening",
    rounds: [
      {
        kind: "hr", state: "completed", days_ago: 5,
        scores: { "communication" => 4, "motivation" => 3, "culture_fit" => 3, "reliability" => 2 },
        recommendation: "maybe",
        notes: "Опыт впечатляющий по разнообразию, но видна job-hopper-pattern. На вопрос почему 5 компаний за 5 лет — отвечает обтекаемо. Сейчас на фрилансе, говорит что хочет стабильности. Soft skills ок, но reliability под вопросом. Технический раунд покажет — возможно стоит сделать с акцентом на современный Rails-стек."
      }
    ]
  },

  # Junior с большим потенциалом — yet-too-junior для senior-роли
  {
    first_name: "Полина", last_name: "Иванова",
    email: "polina.ivanova.dev@example.com",
    phone: "+7 (925) 567-89-01",
    current_company: "Aviasales",
    current_position: "Junior Backend Developer",
    years: 2,
    salary: 180_000,
    location: "Москва",
    source: "referral",
    summary: <<~SUM,
      Junior Backend на Ruby on Rails, 2 года в Aviasales. До этого закончила
      ВШЭ (Прикладная математика и информатика, диплом по ML).

      В Aviasales делала feature-разработку в команде ценообразования: писала
      Rails-сервисы, работала с PostgreSQL, Redis-кешами. Покрытие тестами
      доводила до 95% на новых фичах.

      Активная: организую митап Ruby Junior в Москве (~30 человек), веду
      Telegram-канал про Rails. Очень хочу расти — понимаю что подаюсь на
      позицию выше своего уровня, но готова много учиться.
    SUM
    sections: {
      "Experience" => "Aviasales (2024-now) · Junior Backend, команда ценообразования\nСтажировка в Yandex Search (2023, 6 месяцев)",
      "Skills" => "Ruby/Rails (intermediate), PostgreSQL, RSpec — основы. Python (от учёбы), немного Go.",
      "Education" => "ВШЭ, 2024. Дипломная работа по ranking-моделям для search.",
      "Community" => "Организатор Ruby Junior Meetup MSK. Telegram @railsfromzero (~800 подписчиков)."
    },
    stage: "applied",
    rounds: []
  },

  # Сильный senior — конкурент Дмитрию (для интересного compare)
  {
    first_name: "Антон", last_name: "Кузнецов",
    email: "anton.kuznetsov.dev@example.com",
    phone: "+7 (901) 678-90-12",
    current_company: "Тинькофф",
    current_position: "Senior Backend Developer / Tech Lead",
    years: 8,
    salary: 450_000,
    location: "Москва",
    source: "linkedin",
    summary: <<~SUM,
      8 лет на Ruby on Rails. Последние 4 года в Тинькофф — сейчас Tech Lead
      команды из 5 человек в anti-fraud домене. Архитектор real-time scoring
      системы (200K RPS, p99 < 80ms).

      Глубокий expertise в PostgreSQL (читаю исходники, выступал на PgConf),
      Kafka (3 года в production), distributed systems в целом. Co-author
      книги "Effective Rails" (2024).

      Параллельно — co-founder open-source проекта rails-lens (3.2K⭐).
      Регулярные доклады на RubyRussia, RailsConf. Готов перейти если будет
      интересный продуктовый вызов и масштаб больше моего текущего.
    SUM
    sections: {
      "Experience" => "Тинькофф (2021-now) · Senior → Tech Lead\nMail.ru Group (2017-2021) · Middle → Senior\n\nКлючевые системы: anti-fraud scoring (200K RPS), payment ledger (multi-master), внутренняя BPM-платформа.",
      "Skills" => "Ruby/Rails (expert, contributor), PostgreSQL (advanced — partitioning, replication, internals), Kafka (3y prod), Redis, Kubernetes (operator-разработка), Go (на уровне написания).",
      "Open Source" => "rails-lens (3.2K⭐, co-founder), rspec-rails (8 merged PRs), pg-query-helper (own gem, 800⭐).",
      "Speaking & Books" => "Co-author 'Effective Rails' (2024, Pragmatic Bookshelf). Спикер RubyRussia 2022/2023/2024, RailsConf 2024.",
      "Education" => "МГУ ВМК, магистратура. Курсы CMU 15-721 (DB internals), MIT 6.824 (Distributed Systems)."
    },
    stage: "interview",
    rounds: [
      {
        kind: "hr", state: "completed", days_ago: 8,
        scores: { "communication" => 5, "motivation" => 4, "culture_fit" => 4, "reliability" => 5 },
        recommendation: "strong_yes",
        notes: "Топ-уровень кандидат. Глубоко мыслит, умеет упрощать сложные темы. По мотивации — хочет масштаб больше Тинькофф (что у нас спорный момент, мы поменьше). Reliability железная: 8 лет, 2 компании. Соответствует senior-уровню с запасом."
      },
      {
        kind: "tech", state: "completed", days_ago: 3,
        scores: { "technical_depth" => 5, "problem_solving" => 5, "system_design" => 5, "code_quality" => 5 },
        recommendation: "strong_yes",
        notes: "Безупречно. Прошёлся по PostgreSQL — рассказал про MVCC, vacuum internals, ушёл в WAL-replication. Системный дизайн — спроектировал event-sourcing с CQRS, обсудили 5 разных подходов к идемпотентности. Code-review кейс закрыл за 8 минут с детальными комментариями. Уровень выше senior."
      }
    ]
  }
]

candidates.each do |c|
  applicant = JobApplicant.find_or_initialize_by(company: company, email: c[:email])
  applicant.assign_attributes(
    job_opening:         opening,
    owner:               hr,
    first_name:          c[:first_name],
    last_name:           c[:last_name],
    phone:               c[:phone],
    location:            c[:location],
    current_company:     c[:current_company],
    current_position:    c[:current_position],
    years_of_experience: c[:years],
    expected_salary:     c[:salary],
    currency:            "RUB",
    source:              c[:source],
    summary:             c[:summary],
    stage:               c[:stage],
    applied_at:          rand(8..20).days.ago,
    stage_changed_at:    rand(0..7).days.ago,
    source_meta:         { avatar_url: "https://i.pravatar.cc/300?u=#{c[:email]}" }
  )
  applicant.save!

  applicant.resume.attach(
    io:           StringIO.new(build_resume.call(applicant, c[:sections])),
    filename:     "resume_#{c[:last_name].parameterize}.pdf",
    content_type: "application/pdf"
  )

  c[:rounds].each do |r|
    round = applicant.interview_rounds.find_or_initialize_by(kind: r[:kind])
    round.assign_attributes(
      state:             r[:state],
      scheduled_at:      r[:days_ago].days.ago,
      duration_minutes:  60,
      interviewer:       [hr, admin, manager].compact.sample,
      created_by:        hr,
      location:          ["Google Meet", "Офис, переговорка #2", "Zoom"].sample,
      meeting_url:       "https://meet.google.com/#{SecureRandom.alphanumeric(11)}",
      competency_scores: r[:scores] || {},
      recommendation:    r[:recommendation],
      notes:             r[:notes],
      started_at:        r[:state] == "completed" ? r[:days_ago].days.ago : nil,
      completed_at:      r[:state] == "completed" ? r[:days_ago].days.ago + 1.hour : nil
    )
    round.overall_score = round.calculate_overall_score if r[:scores]&.any?
    round.save!
  end

  puts "✓ #{applicant.full_name} (#{applicant.stage}) · #{applicant.interview_rounds.kept.count} rounds"
end

puts ""
puts "═" * 70
puts "Пул на JOB-DEMO-001 теперь:"
JobApplicant.kept.where(job_opening: opening).order(:expected_salary).each do |a|
  rounds = a.interview_rounds.kept.where(state: "completed").count
  puts "  #{a.full_name.ljust(28)} · #{a.stage.ljust(10)} · #{a.expected_salary.to_i}₽ · #{a.years_of_experience}y exp · #{rounds} раунд(а) с scorecard"
end
puts ""
puts "Открой /job_openings/#{opening.id} — там должна быть кнопка AI-сравнения"
