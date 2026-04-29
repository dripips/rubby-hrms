# Аналитика модуля найма: воронка, time-to-hire, эффективность источников,
# per-recruiter breakdown. Все запросы работают на основе ApplicationStageChange
# и JobApplicant с фильтром по компании и периоду.
class RecruitmentAnalytics
  PERIODS = {
    "30"  => 30,
    "90"  => 90,
    "180" => 180,
    "365" => 365,
    "all" => nil
  }.freeze

  STAGE_ORDER = %w[applied screening interview offered hired].freeze
  TERMINAL_STAGES = %w[hired rejected withdrawn].freeze

  attr_reader :company, :period_days

  def initialize(company:, period: "90")
    @company     = company
    @period_days = PERIODS.fetch(period.to_s, 90)
  end

  # ── KPI карточки сверху страницы ─────────────────────────────────────────
  def kpi_cards
    {
      active:         applicants_in_scope.where(stage: JobApplicant::ACTIVE_STAGES).count,
      hired:          applicants_in_scope.where(stage: "hired").count,
      avg_time_to_hire: avg_time_to_hire,
      hire_rate:      hire_rate
    }
  end

  # ── Воронка: сколько кандидатов прошли каждую стадию + conversion ──────────
  # Считаем по stage_changes — кандидат "достиг" стадии, если был хоть раз
  # переведён в неё ИЛИ в стадию выше по STAGE_ORDER. Берём только активных
  # и завершённых хорошо (hired/offered).
  def funnel
    base_ids = applicants_in_scope.pluck(:id)
    return [] if base_ids.empty?

    # Для каждой стадии — список applicant_id, кто её достиг.
    reach_by_stage = STAGE_ORDER.index_with do |stage|
      reach_set_for(stage, base_ids)
    end

    # applied = всегда все из периода (они подавались)
    reach_by_stage["applied"] = base_ids.to_set

    base_count = reach_by_stage["applied"].size
    STAGE_ORDER.each_with_index.map do |stage, i|
      cnt        = reach_by_stage[stage].size
      prev_cnt   = i.positive? ? reach_by_stage[STAGE_ORDER[i - 1]].size : cnt

      {
        stage: stage,
        label: I18n.t("job_applicants.stages.#{stage}", default: stage.humanize),
        count: cnt,
        of_total_pct:  base_count.zero? ? 0 : (cnt.to_f / base_count * 100).round(1),
        from_prev_pct: i.zero? ? 100.0 : (prev_cnt.zero? ? 0 : (cnt.to_f / prev_cnt * 100).round(1))
      }
    end
  end

  # ── Эффективность источников ─────────────────────────────────────────────
  # На каждый source: общее число кандидатов / нанято / hire-rate%.
  def source_effectiveness
    grouped = applicants_in_scope.group(:source).count
    hired   = applicants_in_scope.where(stage: "hired").group(:source).count
    sources = (grouped.keys + hired.keys).uniq.compact.sort

    sources.map do |src|
      total = grouped[src] || 0
      h     = hired[src] || 0
      {
        source: src,
        label:  I18n.t("job_applicants.sources.#{src}", default: src.humanize),
        total:  total,
        hired:  h,
        rate:   total.zero? ? 0 : (h.to_f / total * 100).round(1)
      }
    end.sort_by { |r| -r[:total] }
  end

  # ── Распределение по стадиям (для donut) ─────────────────────────────────
  def stage_distribution
    counts = applicants_in_scope.group(:stage).count
    total  = counts.values.sum
    JobApplicant::STAGES.map do |stage|
      cnt = counts[stage] || 0
      {
        stage: stage,
        label: I18n.t("job_applicants.stages.#{stage}", default: stage.humanize),
        count: cnt,
        pct:   total.zero? ? 0 : (cnt.to_f / total * 100).round(1)
      }
    end.reject { |r| r[:count].zero? }
  end

  # ── Per-recruiter (owner) breakdown ──────────────────────────────────────
  def recruiter_breakdown
    scope = applicants_in_scope.where.not(owner_id: nil)
    by_owner = scope.group(:owner_id).count
    hired_by = scope.where(stage: "hired").group(:owner_id).count
    interview_by = InterviewRound.kept
                                  .joins(:job_applicant)
                                  .where(job_applicants: { id: scope.pluck(:id) })
                                  .group("job_applicants.owner_id")
                                  .count

    user_map = User.where(id: by_owner.keys).index_by(&:id)
    by_owner.map do |owner_id, total|
      user = user_map[owner_id]
      next nil unless user

      {
        user:       user,
        total:      total,
        hired:      hired_by[owner_id] || 0,
        interviews: interview_by[owner_id] || 0,
        rate:       total.zero? ? 0 : ((hired_by[owner_id] || 0).to_f / total * 100).round(1)
      }
    end.compact.sort_by { |r| -r[:total] }
  end

  # ── Среднее time-to-hire (дни) ───────────────────────────────────────────
  # Считаем как разницу между applied_at и stage_changed_at у hired-кандидатов.
  def avg_time_to_hire
    hired = applicants_in_scope.where(stage: "hired").pluck(:applied_at, :stage_changed_at)
    return nil if hired.empty?

    days = hired.map { |a, h| ((h || Time.current) - a) / 1.day }.reject(&:negative?)
    return nil if days.empty?

    (days.sum / days.size).round(1)
  end

  # ── Hire rate (% нанятых от всех кандидатов в периоде) ────────────────────
  def hire_rate
    total = applicants_in_scope.count
    return 0.0 if total.zero?

    hired = applicants_in_scope.where(stage: "hired").count
    (hired.to_f / total * 100).round(1)
  end

  private

  def applicants_in_scope
    scope = JobApplicant.kept.where(company: company)
    scope = scope.where("applied_at >= ?", period_days.days.ago) if period_days
    scope
  end

  # Множество applicant_id, кто достиг данной стадии (включая стадии выше).
  # Для applied/screening/interview — берем тех, кто либо сейчас на этой стадии,
  # либо прошёл её (есть запись в stage_changes с to_stage = эта или выше).
  def reach_set_for(stage, applicant_ids)
    higher = STAGE_ORDER[STAGE_ORDER.index(stage)..]
    # Те, кто сейчас на одной из этих стадий
    current_ids = JobApplicant.kept.where(id: applicant_ids, stage: higher).pluck(:id)
    # Те, кто проходил через эти стадии (включая текущую) согласно истории
    history_ids = ApplicationStageChange.where(job_applicant_id: applicant_ids,
                                               to_stage: higher).pluck(:job_applicant_id)
    (current_ids + history_ids).to_set
  end
end
