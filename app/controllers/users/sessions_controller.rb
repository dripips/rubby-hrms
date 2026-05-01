class Users::SessionsController < Devise::SessionsController
  layout "auth"

  # Override Devise sign-in:
  #   • password ОК + 2FA выключена → стандартный sign_in + audit
  #   • password ОК + 2FA включена  → sign_out, кладём pending_user_id в сессию,
  #     редирект на /two_factor/challenge
  def create
    self.resource = warden.authenticate!(auth_options)

    if resource.two_factor_enabled?
      remember = params.dig(:user, :remember_me) == "1"
      sign_out(resource)
      session[:otp_pending_user_id]    = resource.id
      session[:otp_pending_started_at] = Time.current.iso8601
      session[:otp_pending_remember]   = remember
      redirect_to two_factor_challenge_path and return
    end

    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    yield resource if block_given?

    AuditLogger.with_request(request) do
      AuditLogger.log!(event: "auth.sign_in", user: resource)
    end

    respond_with resource, location: after_sign_in_path_for(resource)
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
