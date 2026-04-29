class InterviewMailer < ApplicationMailer
  default from: -> { current_smtp_from }

  def scheduled
    @round     = params[:round]
    @applicant = @round.job_applicant
    @recipient = params[:to]
    @subject   = "[HRMS] Интервью назначено: #{@applicant.full_name} · #{@round.kind_label}"
    mail to: @recipient, subject: @subject
  end

  def cancelled
    @round     = params[:round]
    @applicant = @round.job_applicant
    @recipient = params[:to]
    @subject   = "[HRMS] Интервью отменено: #{@applicant.full_name} · #{@round.kind_label}"
    mail to: @recipient, subject: @subject
  end

  # Напоминалка за ~30 мин до встречи. Отправляется фоновым джобом
  # ScheduleInterviewNotificationsJob — рядом с in-app уведомлением.
  def reminder_soon
    @round     = params[:round]
    @applicant = @round.job_applicant
    @recipient = params[:to]
    minutes    = ((@round.scheduled_at - Time.current) / 60).round
    @minutes   = minutes.positive? ? minutes : 0
    @subject   = "[HRMS] Через #{@minutes} мин: #{@round.kind_label} с #{@applicant.full_name}"
    mail to: @recipient, subject: @subject
  end
end
