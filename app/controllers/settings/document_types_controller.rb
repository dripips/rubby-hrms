class Settings::DocumentTypesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_hr
  before_action :set_company
  before_action :set_type, only: %i[edit update destroy]

  def index
    @types = DocumentType.kept.where(company: @company).order(:sort_order, :name)
  end

  def new
    @type = @company.document_types.new(active: true, sort_order: 100)
    authorize @type
  end

  def create
    @type = @company.document_types.new(type_params)
    authorize @type
    if @type.save
      redirect_to settings_document_types_path, notice: t("flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @type.update(type_params)
      redirect_to settings_document_types_path, notice: t("flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @type.discard
    redirect_to settings_document_types_path, notice: t("flash.deleted")
  end

  private

  def set_company  = (@company  = Company.kept.first)
  def set_type
    @type = DocumentType.find(params[:id])
    authorize @type
  end

  def ensure_hr
    return if current_user&.role_superadmin? || current_user&.role_hr?
    redirect_to root_path, alert: t("pundit.not_authorized")
  end

  def type_params
    params.require(:document_type).permit(
      :name, :code, :description, :icon, :extractor_kind,
      :required, :active, :sort_order, :default_validity_months
    )
  end
end
