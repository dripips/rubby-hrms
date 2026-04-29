require "faker"
Faker::Config.locale = "ru"

company   = Company.kept.first
admin     = User.find_by(email: "admin@hrms.local")
hr        = User.find_by(email: "hr@hrms.local")
manager   = User.find_by(email: "manager@hrms.local")

dept = ->(code) { Department.find_by!(company: company, code: code) }
pos  = ->(code) { Position.find_by!(company: company, code: code) }
grd  = ->(level) { Grade.find_by!(company: company, level: level) }

openings_data = [
  { code: "JOB-0001", title: "Senior Backend Developer", dept: "ENG_BACK", pos: "DEV_BACK",  grade: 3, owner: hr,      slots: 2, state: :open,    sf: 220_000, st: 320_000, desc: "Ищем сильного бэкенд-разработчика на Ruby on Rails." },
  { code: "JOB-0002", title: "Frontend Lead",            dept: "ENG_FRONT", pos: "DEV_FRONT", grade: 4, owner: manager, slots: 1, state: :open,    sf: 280_000, st: 400_000, desc: "Ведущий фронтендер с опытом архитектуры SPA и менторинга." },
  { code: "JOB-0003", title: "QA Engineer",              dept: "ENG_QA",  pos: "QA_ENG",   grade: 2, owner: hr,      slots: 1, state: :open,    sf: 130_000, st: 200_000, desc: "Тестирование веб-приложений, автотесты на RSpec/Capybara." },
  { code: "JOB-0004", title: "Product Designer",         dept: "PRODUCT", pos: "DESIGNER", grade: 3, owner: hr,      slots: 1, state: :on_hold, sf: 180_000, st: 260_000, desc: "Продуктовый дизайнер с сильным портфолио SaaS." }
]

openings_data.each do |o|
  rec = JobOpening.find_or_initialize_by(company: company, code: o[:code])
  rec.assign_attributes(
    title:           o[:title],
    department:      dept.call(o[:dept]),
    position:        pos.call(o[:pos]),
    grade:           grd.call(o[:grade]),
    owner:           o[:owner],
    openings_count:  o[:slots],
    state:           o[:state],
    description:     o[:desc],
    requirements:    "Опыт от 3 лет, английский B2, командная работа.",
    nice_to_have:    "Open-source контрибуции, выступления на митапах.",
    salary_from:     o[:sf],
    salary_to:       o[:st],
    currency:        "RUB",
    employment_type: "full_time",
    published_at:    o[:state] == :open ? 14.days.ago.to_date : nil
  )
  rec.save!
end

opening_ids = JobOpening.kept.where(company: company).pluck(:code, :id).to_h

# 25 кандидатов: 8 связаны с конкретной вакансией, остальные — talent pool.
# Распределяем по стадиям.
stages_distribution = {
  "applied"   => 12,
  "screening" => 6,
  "interview" => 4,
  "offered"   => 1,
  "hired"     => 1,
  "rejected"  => 1
}

linked_to = [
  "JOB-0001", "JOB-0001", "JOB-0001",
  "JOB-0002", "JOB-0002",
  "JOB-0003", "JOB-0003",
  "JOB-0004"
].dup

sources = %w[manual careers_page hh linkedin referral email]
owners  = [hr, manager, admin].compact

recruiter_pool = User.kept.where(role: %i[hr superadmin manager]).to_a

stage_counter = 0
if JobApplicant.where(company: company).count >= 25
  # destroy_all чистит ActiveStorage attachments и каскад через dependent: :destroy
  JobApplicant.where(company: company).find_each(&:destroy)
end

# Минимальное демо-резюме (Prawn) — одностраничный PDF с ФИО, контактами и опытом.
build_resume_pdf = lambda do |applicant|
  Prawn::Document.new(page_size: "A4", margin: 48) do |pdf|
    pdf.font_families.update(
      "Arial" => {
        normal: Rails.root.join("vendor/fonts/Arial.ttf").to_s,
        bold:   Rails.root.join("vendor/fonts/Arial-Bold.ttf").to_s
      }
    )
    pdf.font "Arial"
    pdf.fill_color "1d1d1f"

    pdf.font_size(28) { pdf.text applicant.full_name, style: :bold }
    pdf.move_down 4
    pdf.fill_color "6e6e73"
    pdf.font_size(13) { pdf.text "#{applicant.current_position} · #{applicant.current_company}" }
    pdf.fill_color "1d1d1f"
    pdf.move_down 18

    pdf.stroke_color "d2d2d7"
    pdf.stroke_horizontal_rule
    pdf.move_down 12

    pdf.font_size(10) do
      pdf.fill_color "6e6e73"
      pdf.text "CONTACTS", style: :bold, character_spacing: 1
      pdf.fill_color "1d1d1f"
      pdf.move_down 4
      [
        ["Email",     applicant.email],
        ["Phone",     applicant.phone],
        ["Location",  applicant.location],
        ["LinkedIn",  applicant.linkedin_url],
        ["GitHub",    applicant.github_url],
        ["Portfolio", applicant.portfolio_url]
      ].compact.each do |label, value|
        next if value.blank?
        pdf.text "<b>#{label}:</b> #{value}", inline_format: true, leading: 2
      end
    end

    pdf.move_down 18
    pdf.stroke_horizontal_rule
    pdf.move_down 12

    pdf.font_size(10) do
      pdf.fill_color "6e6e73"
      pdf.text "SUMMARY", style: :bold, character_spacing: 1
      pdf.fill_color "1d1d1f"
      pdf.move_down 4
      pdf.text applicant.summary.to_s, leading: 4
    end

    pdf.move_down 18
    pdf.stroke_horizontal_rule
    pdf.move_down 12

    pdf.font_size(10) do
      pdf.fill_color "6e6e73"
      pdf.text "EXPERIENCE", style: :bold, character_spacing: 1
      pdf.fill_color "1d1d1f"
      pdf.move_down 4
      pdf.text "<b>#{applicant.current_position}</b> — #{applicant.current_company}", inline_format: true
      pdf.text "#{applicant.years_of_experience} years · expected salary #{applicant.expected_salary.to_i} #{applicant.currency}"
      pdf.move_down 6
      pdf.text "* Designed and shipped production features end-to-end"
      pdf.text "* Mentored juniors, code reviews, RFC ownership"
      pdf.text "* Cross-functional work with product/design/QA"
    end
  end.render
end

stages_distribution.each do |stage, count|
  count.times do
    gender = [:male, :female].sample

    last  = gender == :female ? Faker::Name.last_name + "а" : Faker::Name.last_name
    first = gender == :female ? Faker::Name.female_first_name : Faker::Name.male_first_name

    code = linked_to.shift
    opening_id = code ? opening_ids[code] : nil

    photo_seed = SecureRandom.alphanumeric(8)

    applicant = JobApplicant.create!(
      company:             company,
      job_opening_id:      opening_id,
      owner:               owners.sample,
      first_name:          first,
      last_name:           last,
      email:               Faker::Internet.unique.email(domain: "example.com"),
      phone:               Faker::PhoneNumber.cell_phone,
      location:            ["Москва", "Санкт-Петербург", "Казань", "Новосибирск", "Удалённо"].sample,
      current_company:     Faker::Company.name,
      current_position:    ["Backend Developer", "Frontend Developer", "QA Engineer", "Product Designer", "Project Manager"].sample,
      years_of_experience: rand(2..12),
      expected_salary:     [120_000, 180_000, 220_000, 280_000, 350_000].sample,
      portfolio_url:       "https://#{Faker::Internet.domain_name}",
      linkedin_url:        "https://linkedin.com/in/#{Faker::Internet.username}",
      github_url:          "https://github.com/#{Faker::Internet.username}",
      source:              sources.sample,
      summary:             Faker::Lorem.paragraph(sentence_count: 3),
      stage:               stage,
      overall_score:       %w[interview offered hired].include?(stage) ? rand(60..95) : nil,
      applied_at:          rand(2..40).days.ago,
      stage_changed_at:    rand(0..14).days.ago,
      source_meta:         { avatar_url: "https://i.pravatar.cc/200?u=#{photo_seed}" }
    )

    # Демо-резюме (PDF) — Prawn рендерит на лету.
    applicant.resume.attach(
      io:           StringIO.new(build_resume_pdf.call(applicant)),
      filename:     "resume_#{applicant.last_name.parameterize}.pdf",
      content_type: "application/pdf"
    )

    # История переходов
    if stage != "applied"
      flow = case stage
             when "screening" then %w[applied screening]
             when "interview" then %w[applied screening interview]
             when "offered"   then %w[applied screening interview offered]
             when "hired"     then %w[applied screening interview offered hired]
             when "rejected"  then ["applied", %w[screening interview].sample, "rejected"]
             end
      flow.each_cons(2).each_with_index do |(from, to), i|
        ApplicationStageChange.create!(
          job_applicant: applicant,
          user:          recruiter_pool.sample,
          from_stage:    from,
          to_stage:      to,
          comment:       (i == flow.length - 2 ? Faker::Lorem.sentence : nil),
          changed_at:    (flow.length - i).days.ago
        )
      end
    end

    # 1-2 заметки на топовых кандидатов
    if %w[interview offered hired].include?(stage) && rand < 0.7
      rand(1..2).times do
        ApplicantNote.create!(
          job_applicant: applicant,
          author:        recruiter_pool.sample,
          body:          Faker::Lorem.paragraph(sentence_count: 2)
        )
      end
    end

    # Раунды интервью: разные паттерны под текущую стадию.
    # interview-кандидаты получают HR-завершён + tech-запланирован,
    # offered/hired — полную цепочку HR/tech/cultural/final с scorecard,
    # rejected — HR-завершён со strong_no.
    if defined?(InterviewRound)
      generate_round = lambda do |kind:, state:, scheduled_at:, fill_scorecard: false, recommendation: nil|
        comps = InterviewRound::COMPETENCY_TEMPLATES[kind]
        scores = fill_scorecard ? comps.each_with_object({}) { |c, h| h[c] = rand(2..5) } : {}
        round = applicant.interview_rounds.build(
          kind:             kind,
          state:            state,
          scheduled_at:     scheduled_at,
          duration_minutes: [45, 60, 90].sample,
          interviewer:      recruiter_pool.sample,
          created_by:       hr || admin,
          location:         ["Зум", "Офис, переговорка 3.14", "Google Meet"].sample,
          meeting_url:      "https://meet.google.com/#{SecureRandom.alphanumeric(10)}",
          competency_scores: scores,
          recommendation:   recommendation,
          notes:            fill_scorecard ? Faker::Lorem.paragraph(sentence_count: 3) : nil,
          decision_comment: fill_scorecard ? Faker::Lorem.sentence : nil,
          started_at:       state == "in_progress" ? scheduled_at : (fill_scorecard ? scheduled_at : nil),
          completed_at:     state == "completed" ? scheduled_at + 1.hour : nil
        )
        round.overall_score = round.calculate_overall_score if fill_scorecard
        round.save!
      end

      case stage
      when "interview"
        generate_round.call(kind: "hr",   state: "completed", scheduled_at: 5.days.ago,    fill_scorecard: true, recommendation: %w[yes maybe].sample)
        generate_round.call(kind: "tech", state: "scheduled", scheduled_at: 2.days.from_now)
      when "offered"
        generate_round.call(kind: "hr",       state: "completed", scheduled_at: 14.days.ago, fill_scorecard: true, recommendation: "yes")
        generate_round.call(kind: "tech",     state: "completed", scheduled_at: 9.days.ago,  fill_scorecard: true, recommendation: "yes")
        generate_round.call(kind: "cultural", state: "completed", scheduled_at: 4.days.ago,  fill_scorecard: true, recommendation: "yes")
        generate_round.call(kind: "final",    state: "scheduled", scheduled_at: 1.day.from_now)
      when "hired"
        %w[hr tech cultural final].each_with_index do |k, i|
          generate_round.call(kind: k, state: "completed",
                              scheduled_at: (24 - i * 5).days.ago,
                              fill_scorecard: true,
                              recommendation: %w[yes strong_yes].sample)
        end
      when "rejected"
        if rand < 0.5
          generate_round.call(kind: %w[hr tech].sample, state: "completed",
                              scheduled_at: rand(5..15).days.ago,
                              fill_scorecard: true, recommendation: %w[no strong_no].sample)
        end
      end
    end

    stage_counter += 1
  end
end

puts "[seed] job_openings: #{JobOpening.kept.where(company: company).count}"
puts "[seed] job_applicants: #{JobApplicant.kept.where(company: company).count}"
puts "[seed] stage_changes: #{ApplicationStageChange.count}"
puts "[seed] applicant_notes: #{ApplicantNote.kept.count}"
puts "[seed] interview_rounds: #{InterviewRound.kept.count}" if defined?(InterviewRound)
