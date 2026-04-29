class Settings::LanguagesController < SettingsController
  before_action :set_language, only: %i[edit update destroy set_default toggle]

  def index
    @languages = Language.ordered
    @new_language = Language.new(enabled: true)
  end

  def new
    @language = Language.new(enabled: true)
  end

  def create
    @language = Language.new(language_params)
    if @language.save
      Language.bust_cache!
      redirect_to settings_languages_path, notice: t("settings.languages.created", default: "Язык добавлен")
    else
      @languages = Language.ordered
      render :index, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @language.update(language_params)
      Language.bust_cache!
      redirect_to settings_languages_path, notice: t("settings.languages.updated", default: "Язык обновлён")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def set_default
    Language.transaction do
      Language.where.not(id: @language.id).update_all(is_default: false)
      @language.update!(is_default: true, enabled: true)
    end
    Language.bust_cache!
    redirect_to settings_languages_path, notice: t("settings.languages.default_set", default: "Язык по умолчанию изменён")
  end

  def toggle
    @language.update!(enabled: !@language.enabled)
    Language.bust_cache!
    redirect_to settings_languages_path
  end

  def destroy
    if @language.is_default?
      redirect_to settings_languages_path, alert: t("settings.languages.cannot_remove_default", default: "Нельзя удалить язык по умолчанию")
    else
      @language.discard
      Language.bust_cache!
      redirect_to settings_languages_path, notice: t("settings.languages.removed", default: "Язык удалён")
    end
  end

  private

  def set_language
    @language = Language.kept.find(params[:id])
  end

  def language_params
    params.require(:language).permit(:code, :native_name, :english_name, :flag, :direction, :enabled, :position)
  end
end
