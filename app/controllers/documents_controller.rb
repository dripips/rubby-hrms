# Документы сотрудников: HR-only CRUD + actions для разбора (gem)
# и AI-summary как fallback для длинных текстовых документов.
class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company
  before_action :set_document, only: %i[show edit update destroy extract extract_assist summarize apply_extracted review_extracted revoke reactivate]

  def index
    authorize Document
    @document_types  = DocumentType.active.where(company: @company)
    @scope           = policy_scope(Document).includes(:document_type, :documentable).recent_first
    @scope           = filter_scope(@scope)
    @page            = (params[:page] || 1).to_i.clamp(1, 100_000)
    @per             = 30
    @total           = @scope.count
    @documents       = @scope.offset((@page - 1) * @per).limit(@per)

    @expiring_soon   = policy_scope(Document).expiring_soon(30).includes(:document_type, :documentable).limit(10)
    @stats           = build_stats
  end

  def show
    authorize @document
    @history = @document.versions.order(created_at: :desc).limit(20)
  end

  def new
    employee = Employee.kept.find_by(id: params[:employee_id]) if params[:employee_id].present?
    @document = Document.new(documentable: employee, state: "active", confidentiality: "internal")
    authorize @document
    @document_types = DocumentType.active.where(company: @company)
    @employees      = Employee.kept.working.where(company: @company).order(:last_name)
  end

  def create
    @document = Document.new(document_params)
    @document.created_by = current_user
    apply_custom_fields(@document, params[:custom_fields])
    authorize @document

    if @document.save
      enqueue_extraction(@document) if @document.file.attached?
      redirect_to document_path(@document), notice: t("documents.created", default: "Документ загружен")
    else
      @document_types = DocumentType.active.where(company: @company)
      @employees      = Employee.kept.working.where(company: @company).order(:last_name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @document
    @document_types = DocumentType.active.where(company: @company)
  end

  def update
    authorize @document
    apply_custom_fields(@document, params[:custom_fields])
    if @document.update(document_params)
      redirect_to document_path(@document), notice: t("documents.updated", default: "Документ обновлён")
    else
      @document_types = DocumentType.active.where(company: @company)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @document
    @document.discard
    redirect_to documents_path, notice: t("documents.deleted", default: "Документ удалён")
  end

  def extract
    authorize @document, :extract?
    scope = AiLock.for_document(@document)

    unless AiLock.running?(scope)
      AiLock.lock!(scope, kind: "document_extract")
      enqueue_extraction(@document, lock_scope: scope)
      AiLock.broadcast_controls(scope)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "document-extraction-#{@document.id}",
          partial: "documents/extraction_panel",
          locals:  { document: @document }
        )
      end
      format.html { redirect_to document_path(@document) }
    end
  end

  def summarize
    authorize @document, :summarize?
    enqueue_ai_task("document_summary")
    respond_to_extraction_panel
  end

  def extract_assist
    authorize @document, :summarize?
    enqueue_ai_task("document_extract_assist")
    respond_to_extraction_panel
  end

  # Полноэкранный preview-форма: pre-filled значения из extracted_data слева,
  # большая картинка/PDF справа. Юзер правит и нажимает Сохранить — улетает в
  # стандартный update.
  def review_extracted
    authorize @document, :update?

    data    = @document.extracted_data.to_h.reject { |k, _| k.to_s.start_with?("_") }
    prefill = build_updates_from_extracted(data)
    @document.assign_attributes(prefill)
    @extracted_data = data
    @document_types = DocumentType.active.where(company: @company)
  end

  # Переносит данные из extracted_data в основные поля документа.
  # Перезаписывает существующие значения — пользователь сам нажал кнопку.
  # Невалидные даты молча пропускаются. Возвращаем краткую сводку: что
  # заполнили / что не подошло.
  def apply_extracted
    authorize @document, :update?

    data = @document.extracted_data.to_h.reject { |k, _| k.to_s.start_with?("_") }
    if data.empty?
      redirect_to document_path(@document),
                  alert: t("documents.no_extracted_data", default: "Нет данных для применения — сначала запусти разбор.")
      return
    end

    updates = build_updates_from_extracted(data)

    if updates.any? && @document.update(updates)
      changed = updates.keys.map { |k| t("documents.fields.#{k}", default: k.to_s.humanize) }.join(", ")
      redirect_to document_path(@document),
                  notice: t("documents.extracted_applied", default: "Поля заполнены из разбора: %{fields}", fields: changed)
    else
      redirect_to document_path(@document),
                  alert: t("documents.extracted_not_applicable", default: "В извлечённых данных нет полей, подходящих для документа (number/issuer/issued_at/expires_at).")
    end
  end

  def revoke
    authorize @document, :update?
    @document.revoke! if @document.may_revoke?
    redirect_to document_path(@document), notice: t("documents.revoked", default: "Документ отозван")
  end

  def reactivate
    authorize @document, :update?
    @document.reactivate! if @document.may_reactivate?
    redirect_to document_path(@document), notice: t("documents.reactivated", default: "Документ активирован")
  end

  private

  def set_company
    @company = Company.kept.first
    redirect_to root_path, alert: t("errors.company_missing", default: "Компания не настроена") if @company.nil?
  end

  def set_document
    @document = Document.find(params[:id])
  end

  def document_params
    params.require(:document).permit(
      :title, :document_type_id, :number, :issued_at, :expires_at, :issuer,
      :notes, :state, :confidentiality, :file,
      :documentable_type, :documentable_id
    )
  end

  def filter_scope(scope)
    scope = scope.where(document_type_id: params[:document_type_id]) if params[:document_type_id].present?
    scope = scope.where(state: params[:state])                        if params[:state].present?
    scope = scope.where(documentable_type: "Employee", documentable_id: params[:employee_id]) if params[:employee_id].present?
    if params[:q].present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
      scope = scope.where("documents.title ILIKE :v OR documents.number ILIKE :v OR documents.issuer ILIKE :v", v: like)
    end
    scope
  end

  def build_stats
    base = policy_scope(Document)
    {
      total:    base.count,
      active:   base.where(state: "active").count,
      expired:  base.where(state: "expired").count,
      expiring: base.expiring_soon(30).count
    }
  end

  # Сливает значения custom-полей из формы в extracted_data["_custom"], не
  # затрагивая ключи, которые наполняет gem/AI-extractor (number, issuer, ...).
  def apply_custom_fields(document, raw)
    return unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

    cleaned = raw.to_unsafe_h.transform_values { |v| v.is_a?(String) ? v.strip : v }
    cleaned.reject! { |_, v| v.nil? || v.is_a?(String) && v.empty? }

    data = document.extracted_data.to_h
    data["_custom"] = (data["_custom"].to_h || {}).merge(cleaned)
    document.extracted_data = data
  end

  # Маппинг extracted_data → колонки Document. Учитывает синонимы которые
  # шлёт AI (valid_until → expires_at, employer → issuer для контрактов и т.д.).
  def build_updates_from_extracted(data)
    updates = {}
    updates[:number]     = data["number"].to_s.strip       if data["number"].present?
    updates[:issuer]     = (data["issuer"] || data["employer"] || data["institution"]).to_s.strip.presence
    updates[:issued_at]  = parse_extracted_date(data["issued_at"] || data["start_date"])
    updates[:expires_at] = parse_extracted_date(data["expires_at"] || data["valid_until"] || data["end_date"])

    updates.compact.reject { |_, v| v.is_a?(String) && v.empty? }
  end

  def parse_extracted_date(value)
    return nil if value.blank?
    return value if value.is_a?(Date)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def enqueue_extraction(document, lock_scope: nil)
    return unless document.file.attached?
    return if document.document_type&.extractor_kind == "free"

    # Картинки/сканы — сразу через AI Vision (Tesseract на сканах ненадёжен,
    # одного запроса хватает и на OCR, и на извлечение полей). PDF и прочее —
    # дешёвый gem-путь, AI остаётся ручным fallback'ом.
    if document.file.image? && ai_enabled?
      auto_enqueue_ai(document, kind: "document_extract_assist")
    else
      DocumentExtractionJob.perform_later(document.id, lock_scope: lock_scope)
    end
  end

  def auto_enqueue_ai(document, kind:)
    scope = AiLock.for_document(document)
    return if AiLock.running?(scope)

    AiLock.lock!(scope, kind: kind)
    RunAiTaskJob.perform_later(
      kind:        kind,
      user_id:     current_user.id,
      document_id: document.id,
      lock_scope:  scope
    )
  end

  def ai_enabled?
    setting = AppSetting.fetch(company: @company, category: "ai")
    RecruitmentAi.new(setting: setting).enabled?
  rescue StandardError => e
    Rails.logger.warn("[DocumentsController#ai_enabled?] #{e.class}: #{e.message}")
    false
  end

  # Общий путь для summarize / extract_assist: лок на документе, ставим job
  # с lock_scope, чтобы UI знал про in-flight task. broadcast_controls в
  # ensure-блоке job ререндерит панель.
  def enqueue_ai_task(kind)
    return redirect_to document_path(@document), alert: t("documents.no_file", default: "Файл не приложен") unless @document.file.attached?

    scope = AiLock.for_document(@document)
    return if AiLock.running?(scope)

    AiLock.lock!(scope, kind: kind)
    RunAiTaskJob.perform_later(
      kind:        kind,
      user_id:     current_user.id,
      document_id: @document.id,
      lock_scope:  scope
    )
    AiLock.broadcast_controls(scope)
  end

  def respond_to_extraction_panel
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "document-extraction-#{@document.id}",
          partial: "documents/extraction_panel",
          locals:  { document: @document }
        )
      end
      format.html { redirect_to document_path(@document) }
    end
  end
end
