# Seed: realistic KPI data for dashboard testing.
# Idempotent — safe to re-run. Generates 8 weeks of weekly assignments + evaluations.

company = Company.kept.first || raise("Company missing — run db:seed first")

metrics_data = [
  { code: "SALES_REVENUE",    name: "Sales revenue",      unit: "₽",   target_direction: :maximize, weight_default: 1.5 },
  { code: "DEALS_CLOSED",     name: "Deals closed",       unit: "шт.", target_direction: :maximize, weight_default: 1.0 },
  { code: "RESPONSE_TIME",    name: "Avg response time",  unit: "ч.",  target_direction: :minimize, weight_default: 0.8 },
  { code: "NPS",              name: "Customer NPS",       unit: "%",   target_direction: :maximize, weight_default: 1.2 },
  { code: "DEFECT_RATE",      name: "Defect rate",        unit: "%",   target_direction: :minimize, weight_default: 1.0 },
  { code: "ONTIME_DELIVERY",  name: "On-time delivery",   unit: "%",   target_direction: :target,   weight_default: 1.0 }
]

metrics = metrics_data.map do |attrs|
  m = KpiMetric.find_or_initialize_by(company: company, code: attrs[:code])
  m.assign_attributes(attrs.merge(active: true))
  m.save!
  m
end

employees = Employee.kept.where(company: company).to_a
hr_user   = User.kept.find_by(role: User.roles[:hr]) || User.kept.find_by(role: User.roles[:superadmin])
mgr_user  = User.kept.find_by(role: User.roles[:manager]) || hr_user

# 9 weeks of weekly assignments (incl. current week) + one evaluation per assignment.
8.downto(0) do |weeks_ago|
  week_anchor = weeks_ago.weeks.ago.to_date
  period_start = week_anchor.beginning_of_week
  period_end   = week_anchor.end_of_week

  employees.each do |emp|
    # Each employee gets 2-3 random metrics per week (deterministic by emp.id + week).
    seed = emp.id * 100 + weeks_ago
    rng  = Random.new(seed)
    chosen = metrics.shuffle(random: rng).first(rng.rand(2..3))

    chosen.each do |metric|
      target_value = case metric.code
      when "SALES_REVENUE"   then rng.rand(800_000..1_500_000)
      when "DEALS_CLOSED"    then rng.rand(8..20)
      when "RESPONSE_TIME"   then rng.rand(2..6)
      when "NPS"             then rng.rand(60..85)
      when "DEFECT_RATE"     then rng.rand(1..5)
      when "ONTIME_DELIVERY" then 95
      end

      assignment = KpiAssignment.find_or_initialize_by(
        employee: emp, kpi_metric: metric, period_start: period_start
      )
      next if assignment.persisted? && assignment.kpi_evaluations.any?

      assignment.assign_attributes(
        period_end: period_end,
        target:     target_value,
        weight:     metric.weight_default
      )
      assignment.save!

      # Score: trends upward over time (recent weeks slightly higher).
      base = case weeks_ago
      when 0..2 then rng.rand(70..95)
      when 3..5 then rng.rand(60..90)
      else            rng.rand(45..80)
      end
      # Add per-employee personality bias (some are stars, some struggling).
      bias = (emp.id % 5 == 0 ? 10 : (emp.id % 7 == 0 ? -15 : 0))
      score = (base + bias).clamp(0, 100)

      actual = case metric.code
      when "SALES_REVENUE"   then (target_value.to_f * score / 100).round
      when "DEALS_CLOSED"    then (target_value.to_f * score / 100).round
      when "RESPONSE_TIME"   then (target_value.to_f * (200 - score) / 100).round(1)
      when "NPS"             then score
      when "DEFECT_RATE"     then ((100 - score) / 20.0).round(1)
      when "ONTIME_DELIVERY" then [ score + rng.rand(-3..3), 100 ].min
      end

      evaluator = (rng.rand < 0.5 ? mgr_user : hr_user) || hr_user
      assignment.kpi_evaluations.create!(
        evaluator:    evaluator,
        actual_value: actual,
        score:        score,
        notes:        weeks_ago == 1 ? "Latest weekly evaluation" : nil,
        evaluated_at: period_end.in_time_zone + 18.hours
      )
    end
  end
end

puts "[seed] kpi: metrics=#{KpiMetric.count} assignments=#{KpiAssignment.count} evaluations=#{KpiEvaluation.count}"
