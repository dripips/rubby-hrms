class GridPreferencesController < ApplicationController
  protect_from_forgery with: :null_session, only: %i[show update]

  def show
    key = sanitize_key(params[:key])
    return head(:bad_request) if key.blank?

    render json: GridPreference.fetch_all(user: current_user, key: key)
  end

  def update
    key  = sanitize_key(params[:key])
    kind = params[:kind].to_s

    return head(:bad_request) if key.blank? || GridPreference::KINDS.exclude?(kind)

    GridPreference.put(user: current_user, key: key, kind: kind, data: deep_normalize(params[:data]))
    render json: { ok: true }
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def sanitize_key(raw)
    s = raw.to_s.strip
    s.match?(/\A[a-z0-9_:\-\.]{2,64}\z/i) ? s : nil
  end

  # Tabulator шлёт persistence-данные разных форм:
  #   columns/sort/filter — массив вложенных hash'ей,
  #   page                — целое число,
  #   density             — { value: "compact" }.
  # ActionController::Parameters в массивах требует ручной развёртки.
  def deep_normalize(raw)
    case raw
    when ActionController::Parameters
      raw.permit!.to_h.transform_values { |v| deep_normalize(v) }
    when Array  then raw.map { |v| deep_normalize(v) }
    when Hash   then raw.transform_values { |v| deep_normalize(v) }
    when String
      return {} if raw.empty?
      raw.start_with?("{", "[") ? (JSON.parse(raw) rescue raw) : raw
    when nil    then {}
    else        raw
    end
  end
end
