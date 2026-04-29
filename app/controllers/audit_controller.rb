class AuditController < ApplicationController
  TRACKED_MODELS = %w[
    Company Department Employee
    LeaveRequest
    JobOpening JobApplicant TestAssignment InterviewRound
    KpiMetric KpiAssignment KpiEvaluation
    Document DocumentType Dictionary DictionaryEntry
    AppSetting System
  ].freeze

  EVENTS = %w[create update destroy auth.sign_in auth.sign_out data.exported].freeze
  REVERTABLE_EVENTS = %w[create update destroy].freeze
  PER    = 50

  def index
    authorize PaperTrail::Version

    @period      = (params[:period].presence || "7d").to_s
    @item_type   = params[:item_type].presence
    @event       = params[:event].presence
    @whodunnit   = params[:whodunnit].presence
    @search      = params[:q].presence

    @scope = PaperTrail::Version.order(created_at: :desc)
    @scope = @scope.where(created_at: period_range)             if period_range
    @scope = @scope.where(item_type: @item_type)                if @item_type.present?
    @scope = @scope.where(event: @event)                        if @event.present?
    @scope = @scope.where(whodunnit: @whodunnit)                if @whodunnit.present?
    @scope = @scope.where("CAST(item_id AS TEXT) LIKE ?", "%#{@search}%") if @search.present?

    @total = @scope.count
    @page  = (params[:page] || 1).to_i
    @page  = 1 if @page < 1
    @versions = @scope.offset((@page - 1) * PER).limit(PER).to_a

    @users_index = User.where(id: @versions.map(&:whodunnit).compact.uniq).index_by { |u| u.id.to_s }
    @model_counts_24h = PaperTrail::Version.where(created_at: 24.hours.ago..).group(:item_type).count
  end

  def revert
    version = PaperTrail::Version.find(params[:id])
    authorize version, :update?

    unless REVERTABLE_EVENTS.include?(version.event)
      redirect_to audit_path, alert: t("audit.revert_not_allowed") and return
    end

    if version.reverted_at.present?
      redirect_to audit_path, alert: t("audit.already_reverted") and return
    end

    case version.event
    when "create"
      # Whitelist моделей для отката — защита от unsafe reflection через item_type.
      klass = revertable_class(version.item_type)
      record = klass&.find_by(id: version.item_id)
      record&.destroy!
    when "update"
      reified = version.reify
      raise ActiveRecord::RecordNotFound unless reified
      reified.save!
    when "destroy"
      reified = version.reify(unversioned_attributes: :nil, dup: false)
      raise ActiveRecord::RecordNotFound unless reified
      reified.save!
    end

    version.update!(reverted_at: Time.current, reverted_by: current_user.id.to_s)
    redirect_to audit_path, notice: t("audit.reverted_ok")
  rescue ActiveRecord::RecordNotFound
    redirect_to audit_path, alert: t("audit.revert_target_missing")
  rescue StandardError => e
    Rails.logger.error("[AuditRevert] #{e.class}: #{e.message}")
    redirect_to audit_path, alert: t("audit.revert_failed", error: e.message)
  end

  private

  # Возвращает Ruby-class для имени модели только если оно в TRACKED_MODELS,
  # иначе nil. Гарантия что нельзя константизировать произвольное имя класса
  # из user-controlled item_type (защита от UnsafeReflection).
  def revertable_class(item_type)
    return nil unless TRACKED_MODELS.include?(item_type.to_s)
    item_type.constantize
  rescue NameError
    nil
  end

  def period_range
    today = Time.current
    case @period
    when "1d"  then today - 1.day..today
    when "7d"  then today - 7.days..today
    when "30d" then today - 30.days..today
    when "90d" then today - 90.days..today
    when "all" then nil
    else            today - 7.days..today
    end
  end
end
