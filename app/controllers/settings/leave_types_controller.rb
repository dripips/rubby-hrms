class Settings::LeaveTypesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_hr
  before_action :set_company
  before_action :set_leave_type, only: %i[edit update destroy]

  def index
    @leave_types = LeaveType.kept.where(company: @company).order(:sort_order, :name)
  end

  def new
    @leave_type = @company.leave_types.new(active: true, paid: true, sort_order: 100)
    authorize @leave_type
  end

  def create
    @leave_type = @company.leave_types.new(leave_type_params)
    apply_custom_fields(@leave_type, params[:custom_fields])
    authorize @leave_type
    if @leave_type.save
      redirect_to settings_leave_types_path, notice: t("flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    apply_custom_fields(@leave_type, params[:custom_fields])
    if @leave_type.update(leave_type_params)
      redirect_to settings_leave_types_path, notice: t("flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @leave_type.discard
    redirect_to settings_leave_types_path, notice: t("flash.deleted")
  end

  private

  def set_company    = (@company    = current_company)
  def set_leave_type
    @leave_type = LeaveType.find(params[:id])
    authorize @leave_type
  end

  def ensure_hr
    return if current_user&.role_superadmin? || current_user&.role_hr?
    redirect_to root_path, alert: t("pundit.not_authorized")
  end

  def leave_type_params
    params.require(:leave_type).permit(
      :name, :code, :paid, :requires_doc,
      :default_days_per_year, :color, :active, :sort_order
    )
  end

  def apply_custom_fields(leave_type, raw)
    return unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

    cleaned = raw.to_unsafe_h.transform_values { |v| v.is_a?(String) ? v.strip : v }
    cleaned.reject! { |_, v| v.nil? || (v.is_a?(String) && v.empty?) }
    leave_type.custom_fields = (leave_type.custom_fields.to_h || {}).merge(cleaned)
  end
end
