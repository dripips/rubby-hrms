# Ежедневный обход активных документов: ищет те, у которых expires_at попадает
# в окна 30 / 7 / 0 дней или уже просрочены. Шлёт DocumentExpiringNotifier
# всем HR/superadmin'ам компании. Чтобы не спамить — для каждой комбинации
# (document, days_left) уведомление отправляется только один раз через
# Rails.cache-маркер с TTL 23 часа.
#
# Запуск: config/recurring.yml каждый день в 09:00.
class DocumentExpiryCheckJob < ApplicationJob
  queue_as :default

  WINDOWS = [ 30, 7, 0 ].freeze       # дней до истечения для уведомлений
  EXPIRED_LOOKBACK = 30.days          # уже просроченные за последний месяц
  DEDUPE_TTL       = 23.hours

  def perform
    today = Date.current

    # 1. Уведомляем по окнам 30/7/0
    WINDOWS.each do |days|
      target_date = today + days.days
      Document.kept.where(state: "active", expires_at: target_date).find_each do |doc|
        notify_about(doc, days)
      end
    end

    # 2. Уведомляем про только-что просроченные (которые не были в "0 days" окне)
    Document.kept.where(state: "active")
            .where(expires_at: (today - EXPIRED_LOOKBACK)..(today - 1.day))
            .find_each do |doc|
      days_left = (doc.expires_at - today).to_i  # отрицательное число
      notify_about(doc, days_left)
    end

    Rails.logger.info("[DocumentExpiryCheckJob] complete (#{today})")
  end

  private

  def notify_about(document, days_left)
    cache_key = "doc_expiry_notify:#{document.id}:#{days_left}"
    return unless Rails.cache.write(cache_key, 1, expires_in: DEDUPE_TTL, unless_exist: true)

    recipients = hr_recipients_for(document)
    return if recipients.empty?

    DocumentExpiringNotifier.with(document_id: document.id, days_left: days_left).deliver(recipients)
    Rails.logger.info("[DocumentExpiryCheckJob] doc=#{document.id} days=#{days_left} → #{recipients.size} HR")
  rescue StandardError => e
    Rails.logger.warn("[DocumentExpiryCheckJob] doc=#{document.id} #{e.class}: #{e.message}")
  end

  # HR + superadmin компании, у которых включены in-app уведомления.
  def hr_recipients_for(document)
    company = (document.documentable.try(:company)) || Company.kept.first
    User.where(role: %w[hr superadmin]).select do |u|
      u.respond_to?(:notify_for?) ? u.notify_for?("document_expiring", :in_app) : true
    end
  end
end
