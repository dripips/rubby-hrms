class DepartmentsController < ApplicationController
  before_action :set_company
  before_action :set_department, only: %i[show update destroy]

  TREE_PREF_KEY = "dept-tree-v1".freeze

  def index
    @roots = Department.kept.where(company: @company, parent_id: nil).order(:sort_order, :name)
    @flat  = Department.kept.where(company: @company).order(:name)
    @new_department = Department.new(company: @company)
    @employees = Employee.kept.where(company: @company).order(:last_name).limit(200)

    pref = GridPreference.find_by(user: current_user, key: TREE_PREF_KEY, kind: "expanded")
    @expanded_set = (pref&.data&.dig("ids") || []).map(&:to_i).to_set
  end

  def show
    @children  = @department.children.kept.order(:sort_order, :name)
    @employees = Employee.kept.where(department: @department).order(:last_name)
  end

  def create
    @department = Department.new(department_params.merge(company: @company))
    apply_custom_fields(@department, params[:custom_fields])
    if @department.save
      redirect_to departments_path, notice: t("departments.created", default: "Отдел добавлен")
    else
      redirect_to departments_path, alert: @department.errors.full_messages.to_sentence
    end
  end

  def update
    apply_custom_fields(@department, params[:custom_fields])
    if @department.update(department_params)
      redirect_to departments_path, notice: t("departments.updated", default: "Отдел обновлён")
    else
      redirect_to departments_path, alert: @department.errors.full_messages.to_sentence
    end
  end

  def apply_custom_fields(department, raw)
    return unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

    cleaned = raw.to_unsafe_h.transform_values { |v| v.is_a?(String) ? v.strip : v }
    cleaned.reject! { |_, v| v.nil? || (v.is_a?(String) && v.empty?) }
    department.custom_fields = (department.custom_fields.to_h || {}).merge(cleaned)
  end

  def destroy
    if @department.children.kept.any?
      redirect_to departments_path, alert: t("departments.has_children", default: "Нельзя удалить отдел с подотделами")
    elsif @department.employees.kept.any?
      redirect_to departments_path, alert: t("departments.has_employees", default: "Нельзя удалить отдел с сотрудниками")
    else
      @department.discard
      redirect_to departments_path, notice: t("departments.deleted", default: "Отдел удалён")
    end
  end

  private

  def set_company
    @company = current_company
    redirect_to root_path, alert: "Компания не настроена" if @company.nil?
  end

  def set_department
    @department = Department.kept.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:name, :code, :parent_id, :head_employee_id, :sort_order)
  end
end
