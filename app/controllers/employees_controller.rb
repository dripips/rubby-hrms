class EmployeesController < ApplicationController
  include TabulatorFilterable

  before_action :set_company
  before_action :set_employee, only: %i[show update destroy]

  GRID_FILTER_FIELDS = %w[
    personnel_number full_name email department position grade
    state state_label employment_type employment_type_label
  ].freeze

  def index
    respond_to do |format|
      format.html do
        @departments = Department.kept.where(company: @company).order(:name)
        @positions   = Position.active.where(company: @company)
        @grades      = Grade.active.where(company: @company)
        @managers    = Employee.kept.where(company: @company).order(:last_name)
        @new_employee = Employee.new(company: @company, hired_at: Date.current, state: :active, employment_type: :full_time)
      end
      format.json { render json: tabulator_payload }
      format.csv  { send_data csv_export, filename: "employees-#{Date.current}.csv", type: "text/csv" }
    end
  end

  def show
    @departments  = Department.kept.where(company: @company).order(:name)
    @positions    = Position.active.where(company: @company)
    @grades       = Grade.active.where(company: @company)
    @managers     = Employee.kept.where(company: @company).where.not(id: @employee.id).order(:last_name)
    @leave_types  = LeaveType.active.where(company: @company)
    @genders      = Gender.active.where(company: @company)
    @notes        = @employee.notes.visible_for(current_user).ordered.includes(:author).limit(50)
    @children     = @employee.children.kept.includes(:gender_record).order(:birth_date)
    @all_leaves   = LeaveRequest.kept
                                .where(employee: @employee)
                                .includes(:leave_type)
                                .order(applied_at: :desc, created_at: :desc)
  end

  def create
    @employee = Employee.new(employee_params.merge(company: @company))
    @employee.personnel_number = next_personnel_number if @employee.personnel_number.blank?
    apply_custom_fields(@employee, params[:custom_fields])

    respond_to do |format|
      if @employee.save
        format.html { redirect_to employees_path, notice: t("employees.created", default: "Сотрудник добавлен") }
        format.json { render json: { status: "ok", id: @employee.id } }
      else
        format.html { redirect_to employees_path, alert: @employee.errors.full_messages.to_sentence }
        format.json { render json: { status: "error", errors: @employee.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    apply_custom_fields(@employee, params[:custom_fields])
    if @employee.update(employee_params)
      redirect_to employees_path, notice: t("employees.updated", default: "Сотрудник обновлён")
    else
      redirect_to employees_path, alert: @employee.errors.full_messages.to_sentence
    end
  end

  # Сливает значения custom-полей из формы в employee.custom_fields. Не
  # вытесняет существующие ключи, если соответствующее поле не пришло.
  def apply_custom_fields(employee, raw)
    return unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

    cleaned = raw.to_unsafe_h.transform_values { |v| v.is_a?(String) ? v.strip : v }
    cleaned.reject! { |_, v| v.nil? || (v.is_a?(String) && v.empty?) }
    employee.custom_fields = (employee.custom_fields.to_h || {}).merge(cleaned)
  end

  def destroy
    @employee.discard
    redirect_to employees_path, notice: t("employees.deleted", default: "Сотрудник удалён")
  end

  private

  def set_company
    @company = current_company
    redirect_to root_path, alert: "Компания не настроена" if @company.nil?
  end

  def set_employee
    @employee = Employee.kept.includes(:department, :position, :grade, :manager, :user, :contracts).find(params[:id])
  end

  def employee_params
    params.require(:employee).permit(
      :personnel_number, :last_name, :first_name, :middle_name, :birth_date,
      :gender, :gender_ref_id, :phone, :personal_email, :address,
      :hired_at, :terminated_at, :employment_type, :state,
      :department_id, :position_id, :grade_id, :manager_id, :user_id,
      # Personal & family
      :marital_status, :emergency_contact_name, :emergency_contact_phone,
      :emergency_contact_relation, :hobbies, :shirt_size, :dietary_restrictions,
      :preferred_language, :has_disability, :special_needs,
      # Documents
      :tax_id, :insurance_id, :passport_number, :passport_issued_at,
      :passport_issued_by, :native_city, :education_level, :education_institution,
      # Photo
      :photo
    )
  end

  def next_personnel_number
    last = Employee.where(company: @company).where("personnel_number ~ '^EMP[0-9]+$'")
                   .order(Arel.sql("LENGTH(personnel_number), personnel_number"))
                   .last&.personnel_number
    n = last ? last.gsub(/\D/, "").to_i + 1 : 1
    "EMP#{n.to_s.rjust(3, '0')}"
  end

  # ── Tabulator AJAX response ────────────────────────────────────────────────
  def tabulator_payload
    scope = Employee.kept.where(company: @company)
                    .left_joins(:user, :department, :position, :grade)
                    .includes(:department, :position, :grade, :manager, :user)

    scope = apply_filters(scope, params[:filter])
    scope = apply_sorts(scope,   params[:sort])

    page = (params[:page]  || 1).to_i.clamp(1, 100_000)
    size = (params[:size]  || 50).to_i.clamp(1, 500)
    total = scope.count
    pages = [ (total.to_f / size).ceil, 1 ].max
    rows  = scope.offset((page - 1) * size).limit(size)

    {
      last_page: pages,
      data:      rows.map { |e| employee_json(e) }
    }
  end

  # Tabulator посылает sort/filter как `sort[0][field]=...&sort[0][dir]=...`,
  # Rails парсит это как hash {"0" => {...}}. Достанем оттуда массив.
  def grid_array(raw)
    return [] if raw.blank?
    items = raw.respond_to?(:values) ? raw.values : Array(raw)
    items.map { |i| i.respond_to?(:permit!) ? i.permit!.to_h : i }.select { |i| i.is_a?(Hash) }
  end

  def apply_filters(scope, raw)
    grid_array(raw).each do |f|
      field = f["field"].to_s
      value = f["value"].to_s.strip
      next if value.empty? || GRID_FILTER_FIELDS.exclude?(field)

      like = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"

      case field
      when "personnel_number" then scope = scope.where("employees.personnel_number ILIKE ?", like)
      when "full_name"        then scope = scope.where("employees.last_name ILIKE :v OR employees.first_name ILIKE :v OR employees.middle_name ILIKE :v", v: like)
      when "email"            then scope = scope.where("users.email ILIKE ?", like)
      when "department"       then scope = value.match?(/\A\d+\z/) ? scope.where(employees: { department_id: value }) : scope.where("departments.name ILIKE ?", like)
      when "position"         then scope = value.match?(/\A\d+\z/) ? scope.where(employees: { position_id:   value }) : scope.where("positions.name ILIKE ?",   like)
      when "grade"            then scope = value.match?(/\A\d+\z/) ? scope.where(employees: { grade_id:      value }) : scope.where("grades.name ILIKE ?",      like)
      when "state", "state_label"
        scope = scope.where(employees: { state: Employee.states[value] }) if Employee.states.key?(value)
      when "employment_type", "employment_type_label"
        scope = scope.where(employees: { employment_type: Employee.employment_types[value] }) if Employee.employment_types.key?(value)
      end
    end
    scope
  end

  def apply_sorts(scope, raw)
    sorts = grid_array(raw)
    return scope.order(:last_name, :first_name) if sorts.empty?

    sorts.each do |s|
      dir = s["dir"] == "desc" ? "desc" : "asc"
      clause = case s["field"].to_s
      when "personnel_number"      then "employees.personnel_number #{dir}"
      when "full_name"             then "employees.last_name #{dir}, employees.first_name #{dir}"
      when "email"                 then "users.email #{dir} NULLS LAST"
      when "department"            then "departments.name #{dir} NULLS LAST"
      when "position"              then "positions.name #{dir} NULLS LAST"
      when "grade"                 then "grades.level #{dir} NULLS LAST"
      when "hired_at"              then "employees.hired_at #{dir}"
      when "state_label"           then "employees.state #{dir}"
      when "employment_type_label" then "employees.employment_type #{dir}"
      end
      scope = scope.order(Arel.sql(clause)) if clause
    end
    scope
  end

  def employee_json(e)
    {
      id:               e.id,
      personnel_number: e.personnel_number,
      full_name:        e.full_name,
      initials:         e.initials,
      email:            e.user&.email,
      department:       e.department&.name,
      position:         e.position&.name,
      grade:            e.grade&.name,
      manager:          e.manager&.full_name,
      hired_at:         e.hired_at&.strftime("%d.%m.%Y"),
      state:            e.state,
      state_label:      I18n.t("employees.states.#{e.state}"),
      employment_type:  e.employment_type,
      employment_type_label: I18n.t("employees.employment_types.#{e.employment_type}"),
      phone:            e.phone
    }
  end

  def csv_export
    require "csv"
    CSV.generate(force_quotes: true, col_sep: ";") do |csv|
      csv << %w[Таб№ ФИО Email Отдел Должность Грейд Принят Статус Телефон]
      Employee.kept.where(company: @company).includes(:department, :position, :grade, :user).find_each do |e|
        csv << [ e.personnel_number, e.full_name, e.user&.email, e.department&.name, e.position&.name, e.grade&.name, e.hired_at, I18n.t("employees.states.#{e.state}"), e.phone ]
      end
    end
  end
end
