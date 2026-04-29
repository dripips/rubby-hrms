class Settings::ProcessTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_hr
  before_action :set_company
  before_action :set_template, only: %i[edit update destroy]

  def index
    @templates = ProcessTemplate.for_company(@company).kept.ordered
    @grouped   = @templates.group_by(&:kind)
  end

  def new
    @template = @company.process_templates.new(kind: params[:kind].presence || "onboarding", items: [], active: true)
    authorize @template
  end

  def create
    @template = @company.process_templates.new(template_params)
    authorize @template
    if @template.save
      redirect_to settings_process_templates_path(anchor: @template.kind), notice: t("flash.created", default: "Создано")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @template.update(template_params)
      redirect_to settings_process_templates_path(anchor: @template.kind), notice: t("flash.updated", default: "Обновлено")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @template.discard
    redirect_to settings_process_templates_path, notice: t("flash.deleted", default: "Удалено")
  end

  private

  def set_company  = (@company  = Company.kept.first)
  def set_template
    @template = ProcessTemplate.find(params[:id])
    authorize @template
  end

  def ensure_hr
    return if current_user&.role_superadmin? || current_user&.role_hr?

    redirect_to root_path, alert: t("pundit.not_authorized")
  end

  def template_params
    raw = params.require(:process_template).permit(:name, :kind, :description, :active, :items_json)
    items =
      if raw[:items_json].present?
        begin
          parsed = JSON.parse(raw[:items_json])
          parsed.is_a?(Array) ? parsed : []
        rescue JSON::ParserError
          []
        end
      else
        []
      end
    raw.except(:items_json).merge(items: items)
  end
end
