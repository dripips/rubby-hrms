class JobApplicantsController < ApplicationController
  before_action :set_company
  before_action :set_applicant, only: %i[show update destroy move_stage]

  def index
    authorize JobApplicant
    @applicants = policy_scope(JobApplicant).where(company: @company).includes(:job_opening, :owner).order(applied_at: :desc)
    @form_data  = form_data
    @new_applicant = JobApplicant.new(company: @company)
  end

  def show
    authorize @applicant
    @stage_changes = @applicant.stage_changes.includes(:user).order(changed_at: :desc)
    @notes         = @applicant.notes.kept.includes(:author).order(created_at: :desc)
    @new_note      = ApplicantNote.new(job_applicant: @applicant)
    @form_data     = form_data
  end

  def create
    authorize JobApplicant
    @applicant = JobApplicant.new(applicant_params.merge(company: @company))
    apply_custom_fields(@applicant, params[:custom_fields])
    if @applicant.save
      redirect_to job_applicant_path(@applicant), notice: t("job_applicants.created", default: "Кандидат добавлен")
    else
      redirect_to job_applicants_path, alert: @applicant.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @applicant
    apply_custom_fields(@applicant, params[:custom_fields])
    if @applicant.update(applicant_params)
      redirect_to job_applicant_path(@applicant), notice: t("job_applicants.updated", default: "Кандидат обновлён")
    else
      redirect_to job_applicant_path(@applicant), alert: @applicant.errors.full_messages.to_sentence
    end
  end

  # Сливает значения custom-полей в applicant.custom_fields.
  def apply_custom_fields(applicant, raw)
    return unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

    cleaned = raw.to_unsafe_h.transform_values { |v| v.is_a?(String) ? v.strip : v }
    cleaned.reject! { |_, v| v.nil? || (v.is_a?(String) && v.empty?) }
    applicant.custom_fields = (applicant.custom_fields.to_h || {}).merge(cleaned)
  end

  def destroy
    authorize @applicant
    @applicant.discard
    redirect_to job_applicants_path, notice: t("job_applicants.deleted", default: "Кандидат удалён")
  end

  def move_stage
    authorize @applicant, :move_stage?
    new_stage = params[:stage].to_s
    return head(:bad_request) unless JobApplicant::STAGES.include?(new_stage)

    if @applicant.transition_to!(new_stage, user: current_user, comment: params[:comment])
      notify_candidate_about_stage(new_stage, params[:comment])
      respond_to do |format|
        format.json { render json: { ok: true, stage: @applicant.stage, days_in_stage: @applicant.days_in_stage } }
        format.html { redirect_to job_applicant_path(@applicant), notice: t("job_applicants.stage_moved", default: "Стадия обновлена") }
      end
    else
      head :unprocessable_entity
    end
  rescue AASM::InvalidTransition => e
    respond_to do |format|
      format.json { render json: { ok: false, error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to job_applicant_path(@applicant), alert: e.message }
    end
  end

  private

  # Шлёт письмо кандидату о переходе на другую стадию (через MessageDispatcher,
  # который уважает настройки в Settings → Коммуникации).
  def notify_candidate_about_stage(new_stage, comment)
    event = case new_stage
    when "rejected"  then :candidate_rejected
    when "applied"   then nil # переоткрытие — не шлём, иначе spam
    else :candidate_next_stage
    end
    return unless event

    MessageDispatcher.deliver!(
      event:          event,
      recipient_type: :candidate,
      payload:        { applicant: @applicant, new_stage: new_stage, comment: comment }
    )
  end

  def set_company
    @company = Company.kept.first
    redirect_to root_path, alert: "Компания не настроена" if @company.nil?
  end

  def set_applicant
    @applicant = JobApplicant.kept.includes(:job_opening, :owner).find(params[:id])
  end

  def applicant_params
    params.require(:job_applicant).permit(
      :job_opening_id, :owner_id,
      :first_name, :last_name, :email, :phone, :location,
      :current_company, :current_position, :years_of_experience,
      :expected_salary, :currency, :portfolio_url, :linkedin_url, :github_url, :telegram,
      :source, :summary,
      :photo, :resume, portfolio_files: []
    )
  end

  def form_data
    {
      openings:   JobOpening.kept.where(company: @company).order(:title),
      recruiters: User.kept.where(role: %i[hr superadmin manager])
    }
  end
end
