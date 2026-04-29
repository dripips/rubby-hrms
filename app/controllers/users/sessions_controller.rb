class Users::SessionsController < Devise::SessionsController
  layout "auth"

  def create
    super do |user|
      AuditLogger.with_request(request) do
        AuditLogger.log!(event: "auth.sign_in", user: user)
      end
    end
  end

  def destroy
    user = current_user
    if user
      AuditLogger.with_request(request) do
        AuditLogger.log!(event: "auth.sign_out", user: user)
      end
    end
    super
  end
end
