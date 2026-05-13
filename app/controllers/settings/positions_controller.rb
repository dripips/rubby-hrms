class Settings::PositionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_hr
  before_action :set_company
  before_action :set_position, only: %i[edit update destroy]

  def index
    @positions = Position.kept.where(company: @company).order(:sort_order, :name)
  end

  def new
    @position = @company.positions.new(active: true, sort_order: 100)
    authorize @position
  end

  def create
    @position = @company.positions.new(position_params)
    apply_custom_fields(@position, params[:custom_fields])
    authorize @position
    if @position.save
      redirect_to settings_positions_path, notice: t("flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    apply_custom_fields(@position, params[:custom_fields])
    if @position.update(position_params)
      redirect_to settings_positions_path, notice: t("flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @position.discard
    redirect_to settings_positions_path, notice: t("flash.deleted")
  end

  private

  def set_company  = (@company  = current_company)
  def set_position
    @position = Position.find(params[:id])
    authorize @position
  end

  def ensure_hr
    return if current_user&.role_superadmin? || current_user&.role_hr?
    redirect_to root_path, alert: t("pundit.not_authorized")
  end

  def position_params
    params.require(:position).permit(:name, :code, :category, :active, :sort_order)
  end

  def apply_custom_fields(position, raw)
    return unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

    cleaned = raw.to_unsafe_h.transform_values { |v| v.is_a?(String) ? v.strip : v }
    cleaned.reject! { |_, v| v.nil? || (v.is_a?(String) && v.empty?) }
    position.custom_fields = (position.custom_fields.to_h || {}).merge(cleaned)
  end
end
