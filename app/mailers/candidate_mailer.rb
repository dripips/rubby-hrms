# Письма КАНДИДАТАМ (наружу). От лица компании.
# Отправка идёт через runtime-SMTP, настроенный в Settings → SMTP.
class CandidateMailer < ApplicationMailer
  def test_assignment_sent
    @applicant  = params[:applicant]
    @assignment = params[:assignment]
    @company    = Company.kept.first
    return unless deliverable?

    mail to: @applicant.email,
         subject: "[#{@company&.name}] Тестовое задание: #{@assignment.title}"
  end

  def rejected
    @applicant = params[:applicant]
    @comment   = params[:comment]
    @company   = Company.kept.first
    return unless deliverable?

    mail to: @applicant.email,
         subject: "[#{@company&.name}] Спасибо за интерес"
  end

  def next_stage
    @applicant   = params[:applicant]
    @new_stage   = params[:new_stage]
    @comment     = params[:comment]
    @company     = Company.kept.first
    return unless deliverable?

    stage_label  = I18n.t("job_applicants.stages.#{@new_stage}", default: @new_stage)
    mail to: @applicant.email,
         subject: "[#{@company&.name}] Следующий этап: #{stage_label}"
  end

  def application_received
    @applicant = params[:applicant]
    @opening   = params[:opening]
    @company   = params[:company] || Company.kept.first
    return unless deliverable?

    mail to: @applicant.email,
         subject: "[#{@company&.name}] Спасибо за отклик: #{@opening&.title}"
  end

  private

  def deliverable?
    @applicant&.email.present?
  end
end
