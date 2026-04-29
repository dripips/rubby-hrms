# Запускается по расписанию из config/recurring.yml.
# Сканирует scheduled-раунды интервью и шлёт notifications:
#  • за ~30 минут до старта (5-минутное окно [25, 35] чтобы не пропускать
#    при дрифте крона);
#  • один раз утром в день встречи — "сегодня встреча".
class ScheduleInterviewNotificationsJob < ApplicationJob
  queue_as :default

  def perform
    notify_soon!
    notify_today!
  end

  private

  def notify_soon!
    soon_window = (25.minutes.from_now)..(35.minutes.from_now)
    rounds = InterviewRound.kept
                            .where(state: "scheduled")
                            .where(scheduled_at: soon_window)
                            .where(soon_notified_at: nil)
                            .includes(:interviewer, :job_applicant)

    rounds.each do |round|
      recipients = recipients_for(round)
      next if recipients.empty?

      recipients.each do |user|
        if user.notify_for?("interview_soon", :in_app)
          InterviewSoonNotifier.with(interview_round_id: round.id).deliver(user)
        end

        if user.notify_for?("interview_soon", :email) && user.email.present?
          InterviewMailer.with(round: round, to: user.email).reminder_soon.deliver_later
        end
      end

      round.update_column(:soon_notified_at, Time.current)
    end
  end

  def notify_today!
    today = Time.current.to_date
    rounds = InterviewRound.kept
                            .where(state: "scheduled")
                            .where("scheduled_at::date = ?", today)
                            .where(digest_notified_on: nil)
                            .includes(:interviewer, :job_applicant)

    rounds.each do |round|
      recipients = recipients_for(round)
      next if recipients.empty?

      recipients.each do |user|
        next unless user.notify_for?("interview_tomorrow", :in_app)

        InterviewTomorrowNotifier.with(interview_round_id: round.id).deliver(user)
      end

      round.update_column(:digest_notified_on, today)
    end
  end

  # Получатели — интервьюер + ответственный recruiter (owner кандидата).
  def recipients_for(round)
    [ round.interviewer, round.job_applicant&.owner ].compact.uniq
  end
end
