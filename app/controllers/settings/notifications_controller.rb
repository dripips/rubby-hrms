class Settings::NotificationsController < SettingsController
  def show
  end

  def update
    prefs = (params.dig(:user, :notification_preferences) || {}).to_unsafe_h
    cleaned = prefs.each_with_object({}) do |(kind, channels), acc|
      next unless User::NOTIFICATION_KINDS.key?(kind.to_s)

      acc[kind.to_s] = channels.slice("in_app", "email").transform_values { |v| v == "1" }
    end

    if current_user.update(notification_preferences: cleaned)
      redirect_to settings_notifications_path,
                  notice: t("settings.notifications.updated", default: "Настройки уведомлений сохранены")
    else
      render :show, status: :unprocessable_entity
    end
  end
end
