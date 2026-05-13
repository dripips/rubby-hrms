class JobOpeningsController < ApplicationController
  include TabulatorFilterable

  before_action :set_company
  before_action :set_opening, only: %i[show update destroy open close hold]

  def index
    authorize JobOpening
    @form_data = form_data
    @openings  = policy_scope(JobOpening).where(company: @company).includes(:department, :position, :owner).order(created_at: :desc)
    @new_opening = JobOpening.new(company: @company, state: :draft, openings_count: 1, currency: "RUB")

    respond_to do |format|
      format.html
      format.json { render json: tabulator_payload }
    end
  end

  def show
    authorize @opening
    @applicants  = @opening.job_applicants.kept.order(applied_at: :desc)
    @new_note_target = nil
  end

  def create
    authorize JobOpening
    @opening = JobOpening.new(opening_params.merge(company: @company))
    @opening.code ||= next_code
    if @opening.save
      redirect_to job_opening_path(@opening), notice: t("job_openings.created", default: "Вакансия добавлена")
    else
      redirect_to job_openings_path, alert: @opening.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @opening
    if @opening.update(opening_params)
      redirect_to job_opening_path(@opening), notice: t("job_openings.updated", default: "Вакансия обновлена")
    else
      redirect_to job_opening_path(@opening), alert: @opening.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @opening
    @opening.discard
    redirect_to job_openings_path, notice: t("job_openings.deleted", default: "Вакансия удалена")
  end

  def open
    authorize @opening, :update?
    @opening.update!(state: :open, published_at: Date.current)
    redirect_to job_opening_path(@opening), notice: t("job_openings.opened", default: "Вакансия открыта")
  end

  def close
    authorize @opening, :update?
    @opening.update!(state: :closed)
    redirect_to job_opening_path(@opening), notice: t("job_openings.closed", default: "Вакансия закрыта")
  end

  def hold
    authorize @opening, :update?
    @opening.update!(state: :on_hold)
    redirect_to job_opening_path(@opening), notice: t("job_openings.held", default: "Вакансия поставлена на паузу")
  end

  private

  def set_company
    @company = current_company
    redirect_to root_path, alert: "Компания не настроена" if @company.nil?
  end

  def set_opening
    @opening = JobOpening.kept.find(params[:id])
  end

  def opening_params
    params.require(:job_opening).permit(
      :title, :code, :department_id, :position_id, :grade_id, :owner_id,
      :openings_count, :state, :description, :requirements, :nice_to_have,
      :salary_from, :salary_to, :currency, :employment_type,
      :published_at, :closes_at
    )
  end

  def form_data
    {
      departments: Department.kept.where(company: @company).order(:name),
      positions:   Position.active.where(company: @company),
      grades:      Grade.active.where(company: @company),
      recruiters:  User.kept.where(role: %i[hr superadmin manager])
    }
  end

  def next_code
    last = JobOpening.where(company: @company).where("code ~ '^JOB-[0-9]+$'").order(Arel.sql("LENGTH(code), code")).last&.code
    n = last ? last.gsub(/\D/, "").to_i + 1 : 1
    "JOB-#{n.to_s.rjust(4, '0')}"
  end

  def tabulator_payload
    scope = policy_scope(JobOpening).where(company: @company)
                  .left_joins(:department, :owner)
                  .includes(:department, :position, :owner)

    scope = apply_filters(scope, params[:filter])
    scope = apply_sorts(scope, params[:sort])

    page = (params[:page] || 1).to_i.clamp(1, 100_000)
    size = (params[:size] || 50).to_i.clamp(1, 500)
    total = scope.count
    pages = [ (total.to_f / size).ceil, 1 ].max
    rows  = scope.offset((page - 1) * size).limit(size)

    {
      last_page: pages,
      data: rows.map { |o| opening_json(o) }
    }
  end

  def apply_filters(scope, raw)
    grid_array(raw).each do |f|
      field = f["field"].to_s
      value = f["value"].to_s.strip
      next if value.empty?

      like = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
      case field
      when "code"             then scope = scope.where("job_openings.code ILIKE ?", like)
      when "title"            then scope = scope.where("job_openings.title ILIKE ?", like)
      when "department"       then scope = scope.where(job_openings: { department_id: value }) if value.match?(/\A\d+\z/)
      when "position"         then scope = scope.where(job_openings: { position_id:   value }) if value.match?(/\A\d+\z/)
      when "state", "state_label"
        scope = scope.where(job_openings: { state: JobOpening.states[value] }) if JobOpening.states.key?(value)
      when "openings_count"   then scope = apply_numeric_compare(scope, "job_openings.openings_count", value)
      when "applicants_count" then scope = filter_by_applicants_count(scope, value)
      end
    end
    scope
  end

  def apply_sorts(scope, raw)
    sorts = grid_array(raw)
    return scope.order(created_at: :desc) if sorts.empty?

    sorts.each do |s|
      dir = s["dir"] == "desc" ? "desc" : "asc"
      clause = case s["field"].to_s
      when "code"           then "job_openings.code #{dir}"
      when "title"          then "job_openings.title #{dir}"
      when "department"     then "departments.name #{dir} NULLS LAST"
      when "owner"          then "users.email #{dir} NULLS LAST"
      when "openings_count" then "job_openings.openings_count #{dir}"
      when "state"          then "job_openings.state #{dir}"
      when "published_at"   then "job_openings.published_at #{dir} NULLS LAST"
      end
      scope = scope.order(Arel.sql(clause)) if clause
    end
    scope
  end

  # applicants_count — агрегат, фильтруем через подсчёт + where IN.
  # Тестируем все openings из текущего scope против лимита, чтобы корректно
  # работали "=0" и "<N" (открытия без откликов тоже учитываются).
  def filter_by_applicants_count(scope, raw)
    op, num = parse_numeric_filter(raw)
    return scope unless op

    candidate_ids = scope.pluck(:id)
    return scope.none if candidate_ids.empty?

    counts = JobApplicant.kept.where(job_opening_id: candidate_ids).group(:job_opening_id).count
    matched = candidate_ids.select do |id|
      c = counts[id] || 0
      case op
      when ">=" then c >= num
      when "<=" then c <= num
      when ">"  then c >  num
      when "<"  then c <  num
      when "<>" then c != num
      else           c == num
      end
    end

    scope.where(id: matched)
  end

  def opening_json(o)
    {
      id:               o.id,
      code:             o.code,
      title:            o.title,
      department:       o.department&.name,
      position:         o.position&.name,
      owner:            o.owner&.email,
      openings_count:   o.openings_count,
      applicants_count: o.applicants_count,
      state:            o.state,
      state_label:      I18n.t("job_openings.states.#{o.state}", default: o.state.humanize),
      published_at:     o.published_at&.strftime("%d.%m.%Y"),
      closes_at:        o.closes_at&.strftime("%d.%m.%Y")
    }
  end
end
