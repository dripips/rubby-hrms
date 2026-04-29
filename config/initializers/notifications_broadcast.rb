# Live-обновление колокольчика в topbar при создании любого уведомления.
# Подписывается на after_create_commit базового Noticed::Notification и
# broadcast'ит обновлённый bell-партиал получателю.
Rails.application.config.to_prepare do
  Noticed::Notification.class_eval do
    after_create_commit :broadcast_topbar_bell

    def broadcast_topbar_bell
      return unless recipient.is_a?(User)

      Turbo::StreamsChannel.broadcast_replace_to(
        [recipient, "notifications"],
        target:  "topbar-bell",
        partial: "shared/notifications_bell",
        locals:  { user: recipient }
      )
    rescue StandardError => e
      Rails.logger.warn("[notifications broadcast] #{e.class}: #{e.message}")
    end
  end
end
