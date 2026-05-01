# CRUD для записей внутри справочника. Один контроллер обслуживает оба типа:
# для lookup редактируем key+value+sort_order; для field_schema добавляем
# meta.type / meta.required / meta.hint / meta.options.
class Settings::DictionaryEntriesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_hr
  before_action :set_dictionary
  before_action :set_entry, only: %i[edit update destroy]

  def new
    @entry = @dictionary.entries.new(active: true, sort_order: 100)
    authorize @entry
  end

  def create
    @entry = @dictionary.entries.new(entry_params)
    authorize @entry
    if @entry.save
      redirect_to settings_dictionary_path(@dictionary), notice: t("flash.created")
    else
      @entries   = @dictionary.entries.kept
      @new_entry = @entry
      render "settings/dictionaries/show", status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @entry.update(entry_params)
      redirect_to settings_dictionary_path(@dictionary), notice: t("flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entry.discard
    redirect_to settings_dictionary_path(@dictionary), notice: t("flash.deleted")
  end

  private

  def set_dictionary
    @dictionary = Dictionary.find(params[:dictionary_id])
  end

  def set_entry
    @entry = @dictionary.entries.find(params[:id])
    authorize @entry
  end

  def ensure_hr
    return if current_user&.role_superadmin? || current_user&.role_hr?
    redirect_to root_path, alert: t("pundit.not_authorized")
  end

  # Для field_schema собираем meta из отдельных полей формы; для lookup
  # только key/value/sort_order/active.
  def entry_params
    permitted = params.require(:dictionary_entry).permit(
      :key, :value, :sort_order, :active,
      meta: [ :type, :required, :hint, :options ]
    )

    if @dictionary.field_schema?
      meta = permitted[:meta].to_h
      meta["required"] = ActiveModel::Type::Boolean.new.cast(meta["required"])
      meta["options"]  = meta["options"].to_s.split(/[,\n]/).map(&:strip).reject(&:empty?) if meta["type"] == "select"
      permitted[:meta] = meta
    else
      permitted.delete(:meta)
    end

    permitted
  end
end
