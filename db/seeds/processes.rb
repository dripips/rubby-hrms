# Demo onboarding/offboarding processes. Idempotent: skips employee if active
# process already exists. Marks part of the tasks as done/in_progress so the
# progress bar и "просрочено" счётчики были ненулевые.

company       = Company.kept.first
return unless company

onboard_tpl  = ProcessTemplate.for_company(company).onboarding.kept.active.first
offboard_tpl = ProcessTemplate.for_company(company).offboarding.kept.active.first
unless onboard_tpl && offboard_tpl
  warn "[seeds] process_templates not loaded yet — run db/seeds/process_templates.rb first"
  return
end

admin = User.find_by(email: "admin@hrms.local") || User.first

# ── Helpers ─────────────────────────────────────────────────────────────────

complete_first_n = lambda do |process, n_done, n_in_progress = 0|
  done = process.tasks.order(:position).limit(n_done)
  done.each { |t| t.update_columns(state: "done", completed_at: Time.current) }

  next_batch = process.tasks.order(:position).offset(n_done).limit(n_in_progress)
  next_batch.each { |t| t.update_columns(state: "in_progress") }
end

# ── Onboarding cases ────────────────────────────────────────────────────────

# Кейсы (employee_personnel_number/id, started_offset_days, mentor_personnel_or_id, scenario)
ONBOARDING_CASES = [
  # Только что вышел — ничего не сделано
  { employee_id: 47, started_offset: -3,  mentor_id: 28, done: 1,  in_progress: 1,  state: "active",
    note: "Беляев — 3-й день, на этапе ввода в курс дела" },
  # Середина онбординга — половина задач закрыта, есть просрочка
  { employee_id: 44, started_offset: -45, mentor_id: 27, done: 6,  in_progress: 1,  state: "active",
    note: "Никитина — 1.5 месяца, 50% прогресса, скоро 60-day check-in" },
  # Ближе к завершению — 9 из 11 готово
  { employee_id: 43, started_offset: -75, mentor_id: 27, done: 9,  in_progress: 0,  state: "active",
    note: "Захаров — 75 дней, готовится probation review" },
  # Завершён успешно
  { employee_id: 45, started_offset: -120, mentor_id: 25, done: 11, in_progress: 0, state: "completed",
    note: "Романов — успешно прошёл онбординг" }
].freeze

ONBOARDING_CASES.each do |c|
  emp = Employee.kept.find_by(id: c[:employee_id])
  next unless emp

  if OnboardingProcess.kept.where(employee_id: emp.id, state: %w[draft active]).exists?
    puts "[seeds] onboarding for #{emp.full_name} already active — skipping"
    next
  end

  started = Date.current + c[:started_offset].days
  mentor  = Employee.kept.find_by(id: c[:mentor_id])

  process = OnboardingProcess.create!(
    employee:           emp,
    template:           onboard_tpl,
    mentor:             mentor,
    started_on:         started,
    target_complete_on: started + 90.days,
    state:              "draft",
    created_by:         admin
  )
  process.materialize_from_template!
  process.activate! if process.may_activate?

  complete_first_n.call(process, c[:done], c[:in_progress])

  if c[:state] == "completed"
    process.tasks.where.not(state: %w[done skipped]).update_all(state: "done", completed_at: Time.current)
    process.complete! if process.may_complete?
  end

  puts "[seeds] onboarding: #{emp.full_name.ljust(34)} state=#{process.reload.state.ljust(9)} progress=#{process.progress_percent}% (#{c[:note]})"
end

# ── Offboarding cases ───────────────────────────────────────────────────────

OFFBOARDING_CASES = [
  # Уже стартовал офбординг, пара задач закрыта, до ухода 12 дней
  { employee_id: 42, last_day_offset: 12, reason: "voluntary",     done: 3, in_progress: 1, state: "active",
    exit_risk: 78, note: "Козлова — добровольный, активный KT" },
  # Через 5 дней уход — KT в разгаре
  { employee_id: 32, last_day_offset: 5,  reason: "voluntary",     done: 6, in_progress: 1, state: "active",
    exit_risk: 60, note: "Семёнов — KT почти готов" },
  # Контракт истекает
  { employee_id: 38, last_day_offset: 21, reason: "contract_end",  done: 0, in_progress: 0, state: "draft",
    exit_risk: 45, note: "Фёдорова — черновик, контракт истекает через 3 недели" }
].freeze

OFFBOARDING_CASES.each do |c|
  emp = Employee.kept.find_by(id: c[:employee_id])
  next unless emp

  if OffboardingProcess.kept.where(employee_id: emp.id, state: %w[draft active]).exists?
    puts "[seeds] offboarding for #{emp.full_name} already active — skipping"
    next
  end

  last_day = Date.current + c[:last_day_offset].days

  process = OffboardingProcess.create!(
    employee:        emp,
    template:        offboard_tpl,
    last_day:        last_day,
    reason:          c[:reason],
    state:           "draft",
    exit_risk_score: c[:exit_risk],
    created_by:      admin
  )
  process.materialize_from_template!
  process.activate! if c[:state] == "active" && process.may_activate?

  complete_first_n.call(process, c[:done], c[:in_progress])

  puts "[seeds] offboarding: #{emp.full_name.ljust(34)} state=#{process.reload.state.ljust(9)} progress=#{process.progress_percent}% risk=#{c[:exit_risk]} (#{c[:note]})"
end

puts "[seeds] processes summary: onboarding=#{OnboardingProcess.kept.count}, offboarding=#{OffboardingProcess.kept.count}"
