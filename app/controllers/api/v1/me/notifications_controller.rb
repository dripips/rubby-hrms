class Api::V1::Me::NotificationsController < Api::V1::BaseController
  def index
    scope = current_user.notifications.newest_first
    scope = scope.unread if params[:filter] == "unread"

    render json: paginated(scope) { |n| serialize(n) }
  end

  def read
    notification = current_user.notifications.find(params[:id])
    notification.mark_as_read! unless notification.read?
    render json: serialize(notification)
  end

  def read_all
    current_user.notifications.unread.update_all(read_at: Time.current)
    head :no_content
  end

  private

  def serialize(n)
    {
      "id"         => n.id,
      "type"       => n.type,
      "params"     => n.params,
      "url"        => safe_url(n),
      "message"    => safe_message(n),
      "read_at"    => n.read_at&.iso8601,
      "created_at" => n.created_at&.iso8601
    }
  end

  def safe_url(n)
    n.event.respond_to?(:url) ? n.event.url : nil
  rescue StandardError
    nil
  end

  def safe_message(n)
    n.event.respond_to?(:message) ? n.event.message : nil
  rescue StandardError
    nil
  end
end
