# Письма ВНУТРЕННИМ пользователям (recruiter / hr / manager).
# От имени компании.
class StaffMailer < ApplicationMailer
  def new_application
    @applicant = params[:applicant]
    @opening   = params[:opening]
    @company   = params[:company] || Company.kept.first
    @to        = params[:to]
    return unless @to.present?

    mail to: @to,
         subject: "[#{@company&.name}] Новый отклик: #{@applicant&.full_name} → #{@opening&.title}"
  end
end
