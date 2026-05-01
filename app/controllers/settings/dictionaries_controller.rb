# Универсальные справочники компании. Два типа:
#   • lookup       — простые списки ключ→значение (для select'ов в формах)
#   • field_schema — описывают доп.поля для сущности (Document, Employee, …)
#                    code = "<TargetModel>:<scope>" (e.g. "DocumentType:5")
#
# UI редактирует и тип, и его entries (DictionaryEntry).
class Settings::DictionariesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_hr
  before_action :set_company
  before_action :set_dictionary, only: %i[show edit update destroy suggest apply_suggestions]

  # Известные точки расширения, на которые код умеет навесить custom_fields
  # / lookup-словари. Используется на index-странице для discovery-блока:
  # пользователь видит куда вообще можно добавить компанийную кастомизацию.
  FIELD_SCHEMA_POINTS = [
    { model: "Employee",     scope: "default", label_key: "settings.dictionaries.points.employee",     hint_key: "settings.dictionaries.points.employee_hint" },
    { model: "Department",   scope: "default", label_key: "settings.dictionaries.points.department",   hint_key: "settings.dictionaries.points.department_hint" },
    { model: "Position",     scope: "default", label_key: "settings.dictionaries.points.position",     hint_key: "settings.dictionaries.points.position_hint" },
    { model: "JobApplicant", scope: "default", label_key: "settings.dictionaries.points.applicant",    hint_key: "settings.dictionaries.points.applicant_hint" },
    { model: "LeaveRequest", scope: "default", label_key: "settings.dictionaries.points.leave",        hint_key: "settings.dictionaries.points.leave_hint" }
  ].freeze

  LOOKUP_POINTS = [
    { code: "applicant_sources",        label_key: "settings.dictionaries.lookups.applicant_sources",        hint_key: "settings.dictionaries.lookups.applicant_sources_hint" },
    { code: "marital_statuses",         label_key: "settings.dictionaries.lookups.marital_statuses",         hint_key: "settings.dictionaries.lookups.marital_statuses_hint" },
    { code: "shirt_sizes",              label_key: "settings.dictionaries.lookups.shirt_sizes",              hint_key: "settings.dictionaries.lookups.shirt_sizes_hint" },
    { code: "document_confidentialities", label_key: "settings.dictionaries.lookups.confidentialities",      hint_key: "settings.dictionaries.lookups.confidentialities_hint" },
    { code: "employment_types",         label_key: "settings.dictionaries.lookups.employment_types",         hint_key: "settings.dictionaries.lookups.employment_types_hint" },
    { code: "offboarding_reasons",      label_key: "settings.dictionaries.lookups.offboarding_reasons",      hint_key: "settings.dictionaries.lookups.offboarding_reasons_hint" }
  ].freeze

  # Простой транслит кириллицы (на случай если AI всё-таки вернул кириллический
  # ключ вопреки промпту). Только частые буквы — для нормализации одиночных ляпов.
  CYRILLIC_TRANSLIT = {
    "а" => "a", "б" => "b", "в" => "v", "г" => "g", "д" => "d", "е" => "e",
    "ё" => "e", "ж" => "zh", "з" => "z", "и" => "i", "й" => "y", "к" => "k",
    "л" => "l", "м" => "m", "н" => "n", "о" => "o", "п" => "p", "р" => "r",
    "с" => "s", "т" => "t", "у" => "u", "ф" => "f", "х" => "kh", "ц" => "ts",
    "ч" => "ch", "ш" => "sh", "щ" => "sch", "ъ" => "", "ы" => "y", "ь" => "",
    "э" => "e", "ю" => "yu", "я" => "ya"
  }.freeze

  def index
    authorize Dictionary
    @dictionaries  = Dictionary.kept.where(company: @company).order(:kind, :name)
    @lookups       = @dictionaries.select(&:lookup?)
    @field_schemas = @dictionaries.select(&:field_schema?)

    @schema_points = FIELD_SCHEMA_POINTS.map do |p|
      code = "#{p[:model]}:#{p[:scope]}"
      p.merge(code: code, dictionary: @field_schemas.find { |d| d.code == code })
    end

    @lookup_points = LOOKUP_POINTS.map do |p|
      p.merge(dictionary: @lookups.find { |d| d.code == p[:code] })
    end
  end

  def show
    @entries = @dictionary.entries.kept
    @new_entry = @dictionary.entries.new
  end

  def new
    @dictionary = @company.dictionaries.new(kind: params[:kind].presence_in(Dictionary::KINDS) || "lookup")
    authorize @dictionary
    if @dictionary.field_schema? && params[:target_model].present?
      @dictionary.code = "#{params[:target_model]}:#{params[:target_scope]}"
      @dictionary.name = params[:default_name].presence ||
                         t("settings.dictionaries.default_field_schema_name",
                           default: "Доп.поля для %{target}",
                           target: params[:target_model])
    elsif @dictionary.lookup? && params[:code].present?
      @dictionary.code = params[:code]
      @dictionary.name = params[:default_name].presence || params[:code].to_s.humanize
    end
  end

  def create
    @dictionary = @company.dictionaries.new(dictionary_params)
    authorize @dictionary
    if @dictionary.save
      redirect_to settings_dictionary_path(@dictionary), notice: t("flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @dictionary.update(dictionary_params)
      redirect_to settings_dictionary_path(@dictionary), notice: t("flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @dictionary.discard
    redirect_to settings_dictionaries_path, notice: t("flash.deleted")
  end

  # Чат-bootstrap: HR пишет сообщение, AI отвечает либо уточняющим вопросом,
  # либо полным предложением словарей+схем. Каждый turn — новый AiRun.
  def bootstrap_message
    authorize Dictionary
    text = params[:user_message].to_s.strip
    if text.empty?
      redirect_to settings_dictionaries_path,
                  alert: t("settings.dictionaries.bootstrap.empty_message", default: "Напиши хотя бы пару слов про компанию.")
      return
    end

    scope = AiLock.for_company_bootstrap(@company)
    if AiLock.running?(scope)
      redirect_to settings_dictionaries_path,
                  alert: t("settings.dictionaries.bootstrap.busy", default: "AI ещё думает над прошлым сообщением — подожди немного.")
      return
    end

    AiLock.lock!(scope, kind: "company_bootstrap")
    RunAiTaskJob.perform_later(
      kind:         "company_bootstrap",
      user_id:      current_user.id,
      user_message: text,
      lock_scope:   scope
    )
    AiLock.broadcast_controls(scope)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "company-bootstrap",
          partial: "settings/dictionaries/bootstrap_panel",
          locals:  { company: @company }
        )
      end
      format.html { redirect_to settings_dictionaries_path }
    end
  end

  # Применить proposed: создать словари и записи из последнего успешного
  # AiRun(action=propose). HR может отметить чекбоксами что именно применять
  # (lookups[] и schemas[]), но MVP — применяет всё предложенное.
  def bootstrap_apply
    authorize Dictionary

    run = AiRun.where(kind: "company_bootstrap").successful.recent.first
    payload = run&.payload.is_a?(Hash) ? run.payload : {}
    if payload["action"] != "propose"
      redirect_to settings_dictionaries_path,
                  alert: t("settings.dictionaries.bootstrap.no_proposal", default: "Пока нет proposal от AI — продолжи диалог.")
      return
    end

    selected_lookups = Array(params[:lookups]).map(&:to_s).to_set
    selected_schemas = Array(params[:schemas]).map(&:to_s).to_set

    created_dicts   = 0
    created_entries = 0
    skipped         = []

    Array(payload["lookups"]).each do |lk|
      code = lk["code"].to_s
      next unless selected_lookups.include?(code) || selected_lookups.empty?
      result = upsert_lookup_from_payload(lk)
      created_dicts   += 1 if result[:dict_created]
      created_entries += result[:entries_created]
      skipped.concat(result[:skipped])
    end

    Array(payload["schemas"]).each do |sc|
      code = "#{sc["model"]}:#{sc["scope"]}"
      next unless selected_schemas.include?(code) || selected_schemas.empty?
      result = upsert_schema_from_payload(sc)
      created_dicts   += 1 if result[:dict_created]
      created_entries += result[:entries_created]
      skipped.concat(result[:skipped])
    end

    msg = t("settings.dictionaries.bootstrap.applied",
            default: "Создано словарей: %{dicts}, записей: %{entries}",
            dicts: created_dicts, entries: created_entries)
    if skipped.any?
      msg += " · " + t("settings.dictionaries.ai.skipped", default: "пропущено: %{list}", list: skipped.first(8).join("; "))
    end
    redirect_to settings_dictionaries_path, notice: msg
  end

  # Сбросить чат — soft-discard все bootstrap-AiRun'ы. История стирается, можно
  # начинать диалог заново.
  def bootstrap_reset
    authorize Dictionary
    AiRun.where(kind: "company_bootstrap").update_all(success: false)
    redirect_to settings_dictionaries_path,
                notice: t("settings.dictionaries.bootstrap.reset_done", default: "Диалог очищен. Можно начать заново.")
  end

  # Запросить у AI набор записей для словаря. Job асинхронный — AiLock держит
  # in-flight, broadcast рендерит ai_panel заново когда завершится.
  def suggest
    scope = AiLock.for_dictionary(@dictionary)

    unless AiLock.running?(scope)
      AiLock.lock!(scope, kind: "dictionary_seed")
      RunAiTaskJob.perform_later(
        kind:          "dictionary_seed",
        user_id:       current_user.id,
        dictionary_id: @dictionary.id,
        hint:          params[:hint].to_s,
        lock_scope:    scope
      )
      AiLock.broadcast_controls(scope)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "dictionary-ai-#{@dictionary.id}",
          partial: "settings/dictionaries/ai_panel",
          locals:  { dictionary: @dictionary }
        )
      end
      format.html { redirect_to settings_dictionary_path(@dictionary) }
    end
  end

  # Применить выбранные предложения AI: создать DictionaryEntry'и из payload
  # последнего успешного AiRun для этого словаря. Юзер шлёт массив keys —
  # которые он отметил галочками.
  def apply_suggestions
    selected_keys = Array(params[:keys]).map(&:to_s).reject(&:empty?).to_set

    run = AiRun.where(dictionary_id: @dictionary.id, kind: "dictionary_seed").successful.recent.first
    if run.nil? || !run.payload.is_a?(Hash)
      redirect_to settings_dictionary_path(@dictionary),
                  alert: t("settings.dictionaries.ai.no_suggestions", default: "Нет предложений AI — сначала запусти подбор.")
      return
    end

    proposed = Array(run.payload["proposed_entries"])
    chosen   = proposed.select { |e| selected_keys.include?(e["key"].to_s) }
    if chosen.empty?
      redirect_to settings_dictionary_path(@dictionary),
                  alert: t("settings.dictionaries.ai.nothing_selected", default: "Ничего не выбрано.")
      return
    end

    created = 0
    skipped = []
    base_sort = @dictionary.entries.maximum(:sort_order) || 0

    chosen.each_with_index do |e, idx|
      raw_key = e["key"].to_s
      key = sanitize_entry_key(raw_key)
      if key.blank?
        Rails.logger.warn("[apply_suggestions] empty key after sanitize: '#{raw_key}'")
        skipped << "#{raw_key} (пустой ключ после очистки)"
        next
      end
      if @dictionary.entries.exists?(key: key)
        skipped << "#{key} (уже есть)"
        next
      end

      entry = @dictionary.entries.new(
        key:        key,
        value:      e["value"].to_s.presence || key.humanize,
        sort_order: base_sort + (idx + 1) * 10,
        active:     true
      )

      if @dictionary.field_schema?
        meta = {}
        meta["type"]     = e["type"].presence_in(Dictionary::FIELD_TYPES) || "string"
        meta["required"] = e["required"] == true || e["required"] == "true"
        meta["hint"]     = e["hint"].to_s if e["hint"].present?
        meta["options"]  = Array(e["options"]).map(&:to_s) if meta["type"] == "select" && e["options"]
        entry.meta = meta
      end

      if entry.save
        created += 1
      else
        Rails.logger.warn("[apply_suggestions] #{@dictionary.code} key=#{key}: #{entry.errors.full_messages.to_sentence}")
        skipped << "#{key} (#{entry.errors.full_messages.to_sentence})"
      end
    end

    msg = t("settings.dictionaries.ai.applied", default: "Добавлено записей: %{n}", n: created)
    if skipped.any?
      msg += " · " + t("settings.dictionaries.ai.skipped", default: "пропущено: %{list}", list: skipped.join("; "))
    end
    flash_kind = created.positive? ? :notice : :alert
    redirect_to settings_dictionary_path(@dictionary), flash_kind => msg
  end

  # Создаёт/обновляет lookup-словарь и его записи из payload AI bootstrap.
  # Возвращает { dict_created:, entries_created:, skipped: [] }
  def upsert_lookup_from_payload(lk)
    code = lk["code"].to_s.strip.presence || (return blank_upsert_result)

    dict = @company.dictionaries.find_or_initialize_by(code: code)
    dict_created = dict.new_record?
    dict.kind = "lookup"
    dict.name = lk["name"].to_s.presence || code.humanize
    return blank_upsert_result unless dict.save

    entries_created, skipped = create_entries_for(dict, Array(lk["entries"]))
    { dict_created: dict_created, entries_created: entries_created, skipped: skipped }
  end

  def upsert_schema_from_payload(sc)
    model = sc["model"].to_s.strip.presence || (return blank_upsert_result)
    scope = sc["scope"].to_s.strip.presence || "default"
    code  = "#{model}:#{scope}"

    dict = @company.dictionaries.find_or_initialize_by(code: code)
    dict_created = dict.new_record?
    dict.kind = "field_schema"
    dict.name = sc["name"].to_s.presence || "Доп.поля для #{model}"
    return blank_upsert_result unless dict.save

    entries_created, skipped = create_entries_for(dict, Array(sc["fields"]).map { |f| field_to_entry_payload(f) })
    { dict_created: dict_created, entries_created: entries_created, skipped: skipped }
  end

  # Конвертит field-предложение AI в формат entry payload (key/value/meta).
  def field_to_entry_payload(field)
    {
      "key"      => field["key"],
      "value"    => field["label"],
      "type"     => field["type"],
      "required" => field["required"],
      "hint"     => field["hint"],
      "options"  => field["options"]
    }
  end

  def create_entries_for(dict, entry_payloads)
    created = 0
    skipped = []
    base_sort = dict.entries.maximum(:sort_order) || 0
    entry_payloads.each_with_index do |e, idx|
      raw_key = e["key"].to_s
      key = sanitize_entry_key(raw_key)
      if key.blank?
        skipped << "#{raw_key}(empty)"
        next
      end
      if dict.entries.exists?(key: key)
        skipped << "#{key}(exists)"
        next
      end

      entry = dict.entries.new(
        key:        key,
        value:      e["value"].to_s.presence || key.humanize,
        sort_order: base_sort + (idx + 1) * 10,
        active:     true
      )

      if dict.field_schema?
        meta = {}
        meta["type"]     = e["type"].presence_in(Dictionary::FIELD_TYPES) || "string"
        meta["required"] = e["required"] == true || e["required"] == "true"
        meta["hint"]     = e["hint"].to_s if e["hint"].present?
        meta["options"]  = Array(e["options"]).map(&:to_s) if meta["type"] == "select" && e["options"]
        entry.meta = meta
      end

      if entry.save
        created += 1
      else
        Rails.logger.warn("[bootstrap] #{dict.code} key=#{key}: #{entry.errors.full_messages.to_sentence}")
        skipped << "#{key}(#{entry.errors.full_messages.to_sentence})"
      end
    end
    [ created, skipped ]
  end

  def blank_upsert_result = { dict_created: false, entries_created: 0, skipped: [] }

  # Очищаем ключ под валидацию DictionaryEntry: /\A[a-z][a-z0-9_]*\z/.
  # AI обычно возвращает корректные snake_case latin keys (так в промпте), но
  # на всякий случай нормализуем: транслитим кириллицу, режем CamelCase, заменяем
  # дефисы/пробелы/прочее на _, убираем хвостовые/начальные _, начало должно быть [a-z].
  def sanitize_entry_key(raw)
    s = raw.to_s.strip
    # CamelCase → snake_case (TruckLicenseClass → truck_license_class)
    s = s.gsub(/([a-z\d])([A-Z])/, '\1_\2').gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
    s = s.downcase
    # Кириллица → латиница
    s = s.chars.map { |ch| CYRILLIC_TRANSLIT[ch] || ch }.join
    # Всё нелатинское/нецифровое/неподчёркивание → _
    s = s.gsub(/[^a-z0-9_]/, "_")
    # Сжимаем подряд _, удаляем не-латинский префикс и хвостовые _
    s.squeeze("_").sub(/\A[^a-z]+/, "").sub(/_+\z/, "")
  end

  private

  def set_company    = (@company = Company.kept.first)
  def set_dictionary
    @dictionary = Dictionary.find(params[:id])
    authorize @dictionary
  end

  def ensure_hr
    return if current_user&.role_superadmin? || current_user&.role_hr?
    redirect_to root_path, alert: t("pundit.not_authorized")
  end

  def dictionary_params
    params.require(:dictionary).permit(:code, :name, :description, :kind)
  end
end
