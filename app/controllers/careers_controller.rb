class CareersController < ApplicationController
  layout "careers"

  # Публичный модуль найма — auth/Pundit/время-зону не дёргаем.
  skip_before_action :authenticate_user!
  skip_before_action :set_locale, raise: false
  skip_around_action :switch_time_zone, raise: false

  before_action :set_company_and_careers
  before_action :set_locale_for_careers

  def index
    scope = JobOpening.kept
                      .state_open
                      .where(company: @company)
                      .includes(:department, :position, :grade)

    if params[:q].present?
      q = "%#{params[:q].to_s.strip.downcase}%"
      scope = scope.where("LOWER(title) LIKE :q OR LOWER(description) LIKE :q OR LOWER(requirements) LIKE :q", q: q)
    end

    if params[:department_id].present?
      scope = scope.where(department_id: params[:department_id])
    end

    if params[:employment_type].present?
      scope = scope.where(employment_type: params[:employment_type])
    end

    @available_departments = JobOpening.kept.state_open.where(company: @company)
                                       .joins(:department).distinct
                                       .pluck("departments.id", "departments.name")
    @available_employment_types = JobOpening.kept.state_open.where(company: @company)
                                            .where.not(employment_type: nil)
                                            .distinct.pluck(:employment_type)

    @openings = scope.order(published_at: :desc, created_at: :desc)
                     .page(params[:page]).per(@careers.per_page)
  end

  def show
    @opening  = find_opening_or_404
    return unless @opening
    @applicant = JobApplicant.new
  end

  def create
    @opening  = find_opening_or_404
    return unless @opening

    # Honeypot: если бот заполнил скрытое поле — silent thank-you
    if params[:website].present?
      redirect_to careers_thank_you_path and return
    end

    # Валидация обязательных consent'ов
    missing = required_consents_missing
    if missing.any?
      flash.now[:alert] = t("careers.flash.consents_required", default: "Подтвердите обязательные согласия")
      @applicant = build_applicant
      @applicant.errors.add(:base, t("careers.flash.consents_required", default: "Подтвердите обязательные согласия"))
      render :show, status: :unprocessable_entity and return
    end

    @applicant = build_applicant

    if @applicant.save
      MessageDispatcher.deliver!(
        event:          :application_received,
        recipient_type: :candidate,
        payload:        { applicant: @applicant, opening: @opening, company: @company }
      )
      MessageDispatcher.deliver!(
        event:          :new_application,
        recipient_type: :staff,
        payload:        { applicant: @applicant, opening: @opening, company: @company }
      )
      redirect_to careers_thank_you_path, notice: @careers.t("flash_received", default: t("careers.flash.received", default: "Заявка получена"))
    else
      render :show, status: :unprocessable_entity
    end
  end

  def thank_you
  end

  def page
    @page_data = @careers.page(params[:slug])
    render :page
  end

  private

  def build_applicant
    @opening.job_applicants.new(applicant_params.merge(
      company:    @company,
      source:     "careers_page",
      stage:      "applied",
      applied_at: Time.current,
      owner_id:   @opening.owner_id,
      consents:   collected_consents
    ))
  end

  def collected_consents
    payload = params[:consents] || {}
    payload = payload.to_unsafe_h if payload.respond_to?(:to_unsafe_h)
    @careers.consents.each_with_object({}) do |c, acc|
      key = c["key"]
      acc[key] = payload[key].present? && payload[key] != "0"
    end.merge(
      "submitted_at" => Time.current.iso8601,
      "ip"           => request.remote_ip,
      "user_agent"   => request.user_agent.to_s.first(300)
    )
  end

  def required_consents_missing
    payload = params[:consents] || {}
    payload = payload.to_unsafe_h if payload.respond_to?(:to_unsafe_h)
    @careers.consents.select do |c|
      c["required"] && (payload[c["key"]].blank? || payload[c["key"]] == "0")
    end.map { |c| c["key"] }
  end

  def find_opening_or_404
    opening = JobOpening.kept.state_open.where(company: @company).find_by(code: params[:code]) ||
              JobOpening.kept.state_open.where(company: @company).find_by(id: params[:code])
    unless opening
      render template: "errors/not_found", status: :not_found, layout: "careers" and return nil
    end
    opening
  end

  def applicant_params
    params.require(:job_applicant).permit(
      :first_name, :last_name, :email, :phone, :location,
      :current_company, :current_position, :years_of_experience,
      :expected_salary, :portfolio_url, :linkedin_url, :github_url, :telegram,
      :summary, :resume, portfolio_files: []
    )
  end

  def set_company_and_careers
    @company  = Company.kept.first
    @careers  = CareersSettings.for(@company)
  end

  # Locale из ?locale=ru или cookies, без redirect к sign_in
  def set_locale_for_careers
    requested = params[:locale]
    if requested.present? && I18n.available_locales.map(&:to_s).include?(requested)
      I18n.locale = requested
      cookies.permanent[:locale] = requested
    elsif cookies[:locale].present? && I18n.available_locales.map(&:to_s).include?(cookies[:locale])
      I18n.locale = cookies[:locale]
    else
      I18n.locale = I18n.default_locale
    end
  end
end
