# Промежуточный шаг между password-логином и полной сессией для пользователей с 2FA.
#
# Flow:
#   1. Users::SessionsController#create принимает email+password.
#   2. Если у юзера two_factor_enabled? — sign_out + session[:otp_pending_user_id] = user.id,
#      redirect → /two_factor/challenge.
#   3. show: показываем форму "введи TOTP или backup-код".
#   4. create: проверяем код, при успехе sign_in(user) и редирект на сохранённую after_sign_in цель.
#
# Сессия в pending-state живёт 5 минут (TTL через timestamp). Дальше — повторный логин.
class TwoFactorChallengesController < ApplicationController
  layout "auth"

  PENDING_TTL = 5.minutes

  def show
    return redirect_to(new_user_session_path) unless pending_user

    @user = pending_user
  end

  def create
    user = pending_user
    return redirect_to(new_user_session_path) unless user

    code = params[:otp_code].to_s.strip

    if user.verify_totp(code) || user.consume_backup_code!(code)
      session.delete(:otp_pending_user_id)
      session.delete(:otp_pending_started_at)
      remember = session.delete(:otp_pending_remember)
      sign_in(user, event: :authentication)
      user.remember_me! if remember

      destination = stored_location_for(:user) || dashboard_path
      redirect_to destination, notice: t("devise.sessions.signed_in")
    else
      @user = user
      flash.now[:alert] = t("profile.two_factor.invalid_code", default: "Неверный код. Попробуй ещё раз.")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def pending_user
    return nil unless session[:otp_pending_user_id]
    started = session[:otp_pending_started_at].to_s
    started_at = Time.zone.parse(started) rescue nil

    if started_at.nil? || Time.current - started_at > PENDING_TTL
      session.delete(:otp_pending_user_id)
      session.delete(:otp_pending_started_at)
      return nil
    end

    @pending_user ||= User.find_by(id: session[:otp_pending_user_id])
  end
end
