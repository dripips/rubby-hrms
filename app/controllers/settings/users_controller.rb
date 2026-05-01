# Управление пользователями системы — superadmin only.
# Что делаем: список, смена роли, лок (через discard), инвайт нового, password reset.
class Settings::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_superadmin
  before_action :set_user, only: %i[edit update destroy reactivate send_reset]

  ROLES = %w[superadmin hr manager employee].freeze

  def index
    @users = User.order(role: :asc, email: :asc)
    @stats = {
      total:       @users.size,
      active:      @users.count { |u| u.discarded_at.nil? },
      locked:      @users.count { |u| u.discarded_at.present? },
      with_employee: @users.joins(:employee).count
    }
  end

  def new
    @user = User.new(role: "employee")
  end

  def create
    pass = params[:user][:password].presence || SecureRandom.alphanumeric(16)
    @user = User.new(user_params.merge(password: pass, password_confirmation: pass))
    if @user.save
      flash[:generated_password] = pass if params[:user][:password].blank?
      redirect_to settings_users_path,
                  notice: t("settings.users.created", default: "Пользователь создан. Пароль: %{p}", p: pass)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    permitted = params.require(:user).permit(:email, :role, :locale, :time_zone)
    permitted[:role] = "employee" unless ROLES.include?(permitted[:role])
    if @user.update(permitted)
      redirect_to settings_users_path, notice: t("flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Soft-lock — discard. Залоченные не могут логиниться (override в User#active_for_authentication?).
  def destroy
    if @user == current_user
      redirect_to settings_users_path, alert: t("settings.users.cannot_lock_self", default: "Нельзя залочить самого себя.")
      return
    end
    @user.discard
    redirect_to settings_users_path, notice: t("settings.users.locked", default: "Пользователь заблокирован")
  end

  def reactivate
    @user.undiscard
    redirect_to settings_users_path, notice: t("settings.users.reactivated", default: "Пользователь разблокирован")
  end

  def send_reset
    raw = @user.send_reset_password_instructions
    if raw
      redirect_to settings_users_path, notice: t("settings.users.reset_sent", default: "Письмо для сброса пароля отправлено на %{e}", e: @user.email)
    else
      redirect_to settings_users_path, alert: t("settings.users.reset_failed", default: "Не удалось отправить письмо.")
    end
  end

  private

  def ensure_superadmin
    return if current_user&.role_superadmin?
    redirect_to root_path, alert: t("pundit.not_authorized")
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    permitted = params.require(:user).permit(:email, :role, :locale, :time_zone)
    permitted[:role] = "employee" unless ROLES.include?(permitted[:role])
    permitted
  end
end
