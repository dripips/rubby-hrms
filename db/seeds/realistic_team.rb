# Realistic Russian-named team of 27 employees with photos, families, KPI
# trends, and mixed leave histories. Idempotent — re-run safely.
#
# Cleans up only the data this script owns (employees + their KPI/leaves/
# children/notes). Departments/positions/grades/leave_types/leave_approval_rules
# are preserved so they stay shareable across reseeds.

company = Company.kept.first || raise("Company missing — run db:seed first")
puts "[realistic_team] reseeding for company #{company.name}"

# ── Cleanup -------------------------------------------------------------------
emp_ids = Employee.where(company: company).pluck(:id)
EmployeeNote.where(employee_id: emp_ids).destroy_all
EmployeeChild.where(employee_id: emp_ids).destroy_all
KpiEvaluation.joins(:kpi_assignment).where(kpi_assignments: { employee_id: emp_ids }).delete_all
KpiAssignment.where(employee_id: emp_ids).delete_all
LeaveApproval.where(leave_request: LeaveRequest.where(employee_id: emp_ids)).delete_all
LeaveRequest.where(employee_id: emp_ids).delete_all
LeaveBalance.where(employee_id: emp_ids).delete_all
Contract.where(employee_id: emp_ids).delete_all if defined?(Contract)
TimeEntry.where(employee_id: emp_ids).delete_all if defined?(TimeEntry)
# Break FK from departments.head_employee_id and employees.manager_id back into the soon-to-be-deleted set.
Department.where(company: company).update_all(head_employee_id: nil)
Employee.where(company: company).update_all(manager_id: nil)
# Detach existing user→employee links so user records survive while employees go away.
User.where(id: Employee.where(company: company).where.not(user_id: nil).pluck(:user_id))
Employee.where(company: company).delete_all

# ── Genders ------------------------------------------------------------------
genders = Gender::DEFAULTS.map do |attrs|
  g = Gender.find_or_initialize_by(company: company, code: attrs[:code])
  g.assign_attributes(attrs.merge(active: true))
  g.save!
  g
end
male_g, female_g = genders.first, genders.last

# ── Reference lookups --------------------------------------------------------
departments = Department.kept.where(company: company).index_by(&:name)
positions   = Position.active.where(company: company).index_by(&:name)
grades      = Grade.active.where(company: company).order(:level).to_a
leave_types = LeaveType.active.where(company: company).index_by(&:code)

raise "Departments missing" if departments.empty?
raise "Positions missing"    if positions.empty?
raise "Grades missing"       if grades.empty?

# ── Roster (27 people) -------------------------------------------------------
# Format: [last, first, middle, gender, hired_years_ago, has_children?]
roster = [
  # Founders & leadership
  ["Бобков",     "Вадим",    "Александрович", :m, 7, true],
  ["Лебедев",    "Олег",     "Игоревич",      :m, 6, true],
  ["Морозова",   "Анна",     "Сергеевна",     :f, 5, false],
  # Engineering
  ["Соколов",    "Артём",    "Николаевич",    :m, 4, true],
  ["Кузнецова",  "Екатерина","Викторовна",    :f, 4, true],
  ["Иванов",     "Алексей",  "Сергеевич",     :m, 3, false],
  ["Петров",     "Дмитрий",  "Александрович", :m, 3, true],
  ["Волков",     "Денис",    "Дмитриевич",    :m, 2, false],
  ["Зайцева",    "Мария",    "Викторовна",    :f, 2, false],
  ["Новиков",    "Кирилл",   "Юрьевич",       :m, 2, true],
  # Sales & Marketing
  ["Орлова",     "София",    "Олеговна",      :f, 5, true],
  ["Семёнов",    "Олег",     "Михайлович",    :m, 4, true],
  ["Васильева",  "Юлия",     "Алексеевна",    :f, 3, false],
  ["Михайлова",  "Анастасия","Павловна",      :f, 3, true],
  ["Голубев",    "Роман",    "Викторович",    :m, 2, false],
  # HR & Operations
  ["Попова",     "Дарья",    "Николаевна",    :f, 5, true],
  ["Смирнова",   "Елена",    "Дмитриевна",    :f, 4, true],
  ["Фёдорова",   "Татьяна",  "Андреевна",     :f, 3, false],
  # Design
  ["Богданов",   "Тимур",    "Эдуардович",    :m, 3, false],
  ["Виноградова","Полина",   "Анатольевна",   :f, 2, false],
  # Finance & Legal
  ["Павлов",     "Игорь",    "Романович",     :m, 6, true],
  ["Козлова",    "Ольга",    "Игоревна",      :f, 4, true],
  ["Захаров",    "Андрей",   "Викторович",    :m, 1, false],
  # Junior bench
  ["Никитина",   "Алина",    "Максимовна",    :f, 1, false],
  ["Романов",    "Никита",   "Олегович",      :m, 1, false],
  ["Соловьёва",  "Ева",      "Артёмовна",     :f, 1, false],
  ["Беляев",     "Максим",   "Андреевич",     :m, 0, false]
]

dept_distribution = {
  "Инженерия"        => %w[Инженерия Engineering R&D],
  "Продажи"          => %w[Продажи Sales Маркетинг],
  "HR"               => %w[HR Кадры],
  "Дизайн"           => %w[Дизайн Design],
  "Финансы"          => %w[Финансы Финансовый\ отдел Юридический]
}

# Pick a department from real list, falling back to first available.
pick_department = ->(idx) {
  list = departments.values
  list[idx % list.size]
}
pick_position = ->(role_idx) {
  list = positions.values
  list[role_idx % list.size]
}
pick_grade = ->(years) {
  case years
  when 0..1 then grades.first || grades.sample
  when 2..3 then grades[1] || grades.first
  when 4..5 then grades[2] || grades.last
  else           grades.last
  end
}

hobbies_pool = [
  "Бег, путешествия", "Шахматы, гитара", "Велосипед, фотография",
  "Готовка, чтение", "Йога, медитация", "Сноуборд, лыжи",
  "Плавание, бег", "Программирование, киберспорт", "Рыбалка, охота",
  "Театр, концерты"
]
shirt_sizes = %w[S M L XL XXL]
diets       = ["—", "—", "—", "Вегетарианец", "Без глютена", "Лактозная непереносимость"]
emergency_relations = %w[супруга супруг мать отец брат сестра]

male_first_names_kids   = %w[Артём Максим Михаил Иван Дмитрий Александр Никита Егор Лев Кирилл]
female_first_names_kids = %w[Алина Анна Полина Мария Софья Анастасия Дарья Ева Виктория Кира]

today = Date.current
admin_user = User.kept.find_by(role: User.roles[:superadmin])

# ── Create employees ---------------------------------------------------------
created_employees = []
roster.each_with_index do |(last, first, middle, gender, years, has_kids), idx|
  hired = today - (years.years + rand(0..120).days)
  birth = today - rand(24..52).years - rand(0..364).days

  attrs = {
    company:       company,
    department:    pick_department.call(idx),
    position:      pick_position.call(idx),
    grade:         pick_grade.call(years),
    last_name:     last,
    first_name:    first,
    middle_name:   middle,
    birth_date:    birth,
    gender:        (gender == :m ? :male : :female),
    gender_record: (gender == :m ? male_g  : female_g),
    phone:         "+7 9#{rand(10..99)} #{rand(100..999)}-#{rand(10..99)}-#{rand(10..99)}",
    personal_email: "#{first.downcase.gsub(/[^a-zа-я]/i, '')}.#{last.downcase.gsub(/[^a-zа-я]/i, '')}#{idx}@example.com",
    hired_at:      hired,
    state:         (years.zero? ? :probation : :active),
    employment_type: (idx % 9 == 8 ? :contract : :full_time),
    marital_status:  (has_kids ? %w[married married partnership].sample : %w[single single married].sample),
    hobbies:         hobbies_pool[idx % hobbies_pool.size],
    shirt_size:      shirt_sizes[idx % shirt_sizes.size],
    dietary_restrictions: diets[idx % diets.size],
    tax_id:          rand(10**11...10**12).to_s,
    insurance_id:    "%03d-%03d-%03d %02d" % [rand(1000), rand(1000), rand(1000), rand(100)],
    passport_number: "%04d %06d" % [rand(10**4), rand(10**6)],
    passport_issued_at: birth + 14.years,
    passport_issued_by:  ["ОВД г. Москвы", "УФМС России по Московской области", "ОВД Центрального округа"].sample,
    native_city:     %w[Москва Санкт-Петербург Екатеринбург Новосибирск Казань Воронеж Самара].sample,
    education_level: %w[Высшее Высшее Высшее Среднее\ профессиональное].sample,
    education_institution: ["МГУ", "МФТИ", "СПбГУ", "ВШЭ", "МГТУ\ им.\ Баумана", "УрФУ"].sample,
    emergency_contact_name:    "#{%w[Александр Сергей Дмитрий Елена Анна Ольга].sample} #{last}",
    emergency_contact_phone:   "+7 9#{rand(10..99)} #{rand(100..999)}-#{rand(10..99)}-#{rand(10..99)}",
    emergency_contact_relation: emergency_relations.sample
  }

  emp = Employee.create!(attrs.merge(personnel_number: "EMP%03d" % (idx + 1)))
  created_employees << emp

  # Children: 1-3 for has_kids
  if has_kids
    rand(1..3).times do
      kid_gender = rand < 0.5 ? male_g : female_g
      kid_first  = (kid_gender == male_g ? male_first_names_kids : female_first_names_kids).sample
      kid_birth  = today - rand(1..16).years - rand(0..364).days
      EmployeeChild.create!(
        employee:      emp,
        gender_record: kid_gender,
        first_name:    kid_first,
        last_name:     last,
        birth_date:    kid_birth,
        notes:         (rand < 0.3 ? "Любит #{%w[лего книги футбол рисование плавание].sample}" : nil)
      )
    end
  end
end

# ── Manager hierarchy --------------------------------------------------------
ceo = created_employees[0] # Бобков
cto = created_employees[1] # Лебедев
hr_lead = created_employees[15] # Попова
cto.update!(manager: ceo)
hr_lead.update!(manager: ceo)
created_employees[2].update!(manager: ceo) # Морозова

# Engineering reports to Лебедев
created_employees[3..9].each { |e| e.update!(manager: cto) }
# Sales reports to Морозова (idx 2)
created_employees[10..14].each { |e| e.update!(manager: created_employees[2]) }
# HR + Ops to Попова
created_employees[16..17].each { |e| e.update!(manager: hr_lead) }
# Design to Морозова
created_employees[18..19].each { |e| e.update!(manager: created_employees[2]) }
# Finance reports to CEO
created_employees[20..22].each { |e| e.update!(manager: ceo) }
# Junior bench distributed
created_employees[23..26].each { |e| e.update!(manager: cto) }

# ── Wire devise users to first 4 employees -----------------------------------
%w[admin@hrms.local hr@hrms.local manager@hrms.local alice@hrms.local].each_with_index do |email, i|
  u = User.kept.find_by(email: email)
  next unless u && created_employees[i]
  Employee.where(user_id: u.id).where.not(id: created_employees[i].id).update_all(user_id: nil)
  created_employees[i].update!(user: u)
end

# ── Notes (sample HR observations) -------------------------------------------
note_samples = [
  ["Отлично провёл проект — выделить премию", true,  false],
  ["Запросил гибкий график на ближайшие 2 месяца", true, false],
  ["Хорошо отрабатывает feedback на 1:1", false, false],
  ["Готовится к сертификации, выдать budget на курсы", true, false],
  ["Конфликт с командой решён, стороны помирились", true, true]
]
created_employees.sample(8).each do |emp|
  note_samples.sample(rand(1..2)).each do |body, hr_only, pinned|
    EmployeeNote.create!(
      employee: emp,
      author:   admin_user,
      body:     body,
      hr_only:  hr_only,
      pinned:   pinned
    )
  end
end

# ── Leave history ------------------------------------------------------------
annual = leave_types["ANNUAL"]
sick   = leave_types["SICK"]
admin_user_id = admin_user.id

# 9 not-yet-taken (no leaves at all): the last 9 of roster
not_taken_set = created_employees.last(9).to_set

# Past completed leaves for ~9 employees (mix of annual/sick).
created_employees.first(18).sample(9).each do |emp|
  next if not_taken_set.include?(emp)
  start = today - rand(60..240).days
  ending  = start + rand(5..14).days
  type   = [annual, annual, sick].sample
  next if type.nil?
  LeaveRequest.create!(
    employee:     emp,
    leave_type:   type,
    started_on:   start,
    ended_on:     ending,
    days:         (ending - start + 1).to_i,
    state:        "completed",
    applied_at:   start - 14.days,
    reason:       (type == sick ? "Простуда" : "Отдых")
  )
end

# Half (~13) have an upcoming approved leave.
created_employees.reject { |e| not_taken_set.include?(e) }.sample(13).each do |emp|
  start  = today + rand(7..90).days
  ending = start + rand(5..14).days
  LeaveRequest.create!(
    employee:     emp,
    leave_type:   annual || leave_types.values.first,
    started_on:   start,
    ended_on:     ending,
    days:         (ending - start + 1).to_i,
    state:        "hr_approved",
    applied_at:   today - rand(1..7).days,
    reason:       "Запланированный отпуск"
  )
end

# Couple of pending submitted requests for HR demo.
created_employees.sample(3).each do |emp|
  start  = today + rand(20..60).days
  ending = start + rand(5..10).days
  LeaveRequest.create!(
    employee:     emp,
    leave_type:   annual || leave_types.values.first,
    started_on:   start,
    ended_on:     ending,
    days:         (ending - start + 1).to_i,
    state:        "submitted",
    applied_at:   today - rand(1..3).days,
    reason:       "Семейные обстоятельства"
  )
end

# ── KPI: 12 weeks of evaluations with mixed trends ---------------------------
metrics = KpiMetric.active.where(company: company).to_a
if metrics.any?
  trend_buckets = {
    rising:  created_employees.sample(8),     # score grows over time
    falling: created_employees.sample(6),     # declining
  }
  rising_set  = trend_buckets[:rising].to_set
  falling_set = trend_buckets[:falling].to_set

  12.downto(0).each do |weeks_ago|
    week_start = (today - weeks_ago.weeks).beginning_of_week
    week_end   = week_start.end_of_week

    created_employees.each do |emp|
      seed = emp.id * 137 + weeks_ago
      rng  = Random.new(seed)
      assigned = metrics.shuffle(random: rng).first(rng.rand(2..3))

      assigned.each do |metric|
        target = case metric.code
                 when "SALES_REVENUE"   then 1_000_000
                 when "DEALS_CLOSED"    then 12
                 when "RESPONSE_TIME"   then 4
                 when "NPS"             then 75
                 when "DEFECT_RATE"     then 2
                 when "ONTIME_DELIVERY" then 95
                 else 100
                 end

        a = KpiAssignment.find_or_initialize_by(
          employee: emp, kpi_metric: metric, period_start: week_start
        )
        next if a.persisted? && a.kpi_evaluations.any?
        a.update!(period_end: week_end, target: target, weight: metric.weight_default || 1.0)

        # Score trend logic
        base = if rising_set.include?(emp)
                 # Older weeks = lower score, recent = higher
                 50 + ((12 - weeks_ago) * 4) + rng.rand(-5..5)
               elsif falling_set.include?(emp)
                 # Older weeks = high, recent = lower
                 90 - ((12 - weeks_ago) * 3) + rng.rand(-5..5)
               else
                 60 + rng.rand(0..30)
               end
        score = base.clamp(0, 100)
        actual = (target.to_f * score / 100.0).round(2)

        a.kpi_evaluations.create!(
          evaluator:   admin_user,
          actual_value: actual,
          score:       score,
          notes:       (weeks_ago.zero? ? "Текущая оценка" : nil),
          evaluated_at: week_end.in_time_zone + 18.hours
        )
      end
    end
  end
end

puts "[realistic_team] employees=#{Employee.where(company: company).count} children=#{EmployeeChild.where(employee: Employee.where(company: company).select(:id)).count} notes=#{EmployeeNote.where(employee: Employee.where(company: company).select(:id)).count} leaves=#{LeaveRequest.where(employee: Employee.where(company: company).select(:id)).count} kpi_assignments=#{KpiAssignment.where(employee: Employee.where(company: company).select(:id)).count}"
