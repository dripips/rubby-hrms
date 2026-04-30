# Документы сотрудников: HR-only CRUD + actions для разбора (gem)
# и AI-summary как fallback для длинных текстовых документов.
class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_company
  before_action :set_document, only: %i[show edit update destroy extract summarize revoke reactivate]

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
    enqueue_extraction(@document)
    redirect_to document_path(@document), notice: t("documents.extraction_enqueued", default: "Разбор запущен")
  end

  def summarize
    authorize @document, :summarize?
    # Will be implemented in Phase 4 (AI fallback)
    redirect_to document_path(@document), notice: t("documents.summary_pending", default: "AI-сводка появится через минуту")
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

  def enqueue_extraction(document)
    return unless document.file.attached?
    return if document.document_type&.extractor_kind == "free"

    DocumentExtractionJob.perform_later(document.id)
  end
end
