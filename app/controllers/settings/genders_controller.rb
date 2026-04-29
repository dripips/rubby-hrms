class Settings::GendersController < SettingsController
  before_action :set_company
  before_action :set_gender, only: %i[edit update destroy]

  def index
    @genders = Gender.kept.where(company: @company).order(:sort_order, :name)
    @new_gender = Gender.new(company: @company, active: true, sort_order: (@genders.maximum(:sort_order) || 0) + 1)
  end

  def create
    @gender = Gender.new(gender_params.merge(company: @company))
    if @gender.save
      redirect_to settings_genders_path, notice: t("settings.genders.created")
    else
      redirect_to settings_genders_path, alert: @gender.errors.full_messages.to_sentence
    end
  end

  def edit; end

  def update
    if @gender.update(gender_params)
      redirect_to settings_genders_path, notice: t("settings.genders.updated")
    else
      redirect_to settings_genders_path, alert: @gender.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @gender.employees.kept.any? || @gender.employee_children.kept.any?
      @gender.update(active: false)
      redirect_to settings_genders_path, notice: t("settings.genders.deactivated")
    else
      @gender.discard
      redirect_to settings_genders_path, notice: t("settings.genders.deleted")
    end
  end

  private

  def set_company
    @company = Company.kept.first
  end

  def set_gender
    @gender = Gender.kept.where(company: @company).find(params[:id])
  end

  def gender_params
    params.require(:gender).permit(:code, :name, :pronouns, :avatar_seed, :sort_order, :active)
  end
end
