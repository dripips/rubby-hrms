class NotificationsController < ApplicationController
  before_action :set_notification, only: %i[read destroy]

  def index
    @notifications = current_user.notifications
                                  .order(created_at: :desc)
                                  .page(params[:page])
                                  .per(50) rescue current_user.notifications.order(created_at: :desc).limit(200)
  end

  def read
    @notification.update(read_at: Time.current) if @notification.read_at.nil?

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "topbar-bell",
          partial: "shared/notifications_bell",
          locals:  { user: current_user }
        )
      end
      format.html { redirect_back_or_to notifications_path }
    end
  end

  def mark_all_read
    current_user.notifications.where(read_at: nil).update_all(read_at: Time.current)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "topbar-bell",
          partial: "shared/notifications_bell",
          locals:  { user: current_user }
        )
      end
      format.html { redirect_back_or_to notifications_path }
    end
  end

  def destroy
    @notification.destroy
    redirect_back_or_to notifications_path, notice: t("notifications.deleted", default: "Удалено")
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
