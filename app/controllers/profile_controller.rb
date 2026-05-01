# Self-service портал сотрудника: правит ограниченный набор личных полей
# своей employee-карточки. Ничего про salary/grade/department/manager —
# это только HR. Если у user'а нет связанной Employee — отдаём 404-стиль
# редирект на dashboard.
class ProfileController < ApplicationController
  before_action :authenticate_user!
  before_action :load_employee

  EDITABLE_ATTRIBUTES = %i[
    phone personal_email address marital_status
    hobbies dietary_restrictions shirt_size preferred_language
    emergency_contact_name emergency_contact_phone emergency_contact_relation
    has_disability special_needs gender_ref_id
  ].freeze

  def show
    @genders = Gender.where(company: @employee.company).order(:sort_order, :name)
  end

  def edit
    @genders = Gender.where(company: @employee.company).order(:sort_order, :name)
  end

  def update
    apply_custom_fields(@employee, params[:custom_fields])
    if @employee.update(profile_params)
      redirect_to profile_path, notice: t("profile.updated", default: "Данные обновлены")
    else
      @genders = Gender.where(company: @employee.company).order(:sort_order, :name)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_employee
    @employee = current_user.employee
    return if @employee

    redirect_to dashboard_path,
                alert: t("profile.no_employee", default: "К аккаунту не привязана карточка сотрудника. Обратись в HR.")
  end

  def profile_params
    params.require(:employee).permit(*EDITABLE_ATTRIBUTES)
  end

  # Слив custom-полей в employee.custom_fields (тот же паттерн что в EmployeesController).
  def apply_custom_fields(employee, raw)
    return unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)
    cleaned = raw.to_unsafe_h.transform_values { |v| v.is_a?(String) ? v.strip : v }
    cleaned.reject! { |_, v| v.nil? || (v.is_a?(String) && v.empty?) }
    employee.custom_fields = (employee.custom_fields.to_h || {}).merge(cleaned)
  end
end
