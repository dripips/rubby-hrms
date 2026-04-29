# Universal logger for non-CRUD audit events (auth, exports, sends, etc.)
# Writes directly to PaperTrail::Version with synthetic item_type to keep a
# single audit feed UI. Supports a per-request execution context that captures
# IP / User-Agent / request-id so any service-layer call gets enriched.
module AuditLogger
  module_function

  THREAD_KEY = :audit_logger_request_context

  def with_request(request, &block)
    Thread.current[THREAD_KEY] = {
      ip:         request.respond_to?(:remote_ip)  ? request.remote_ip       : nil,
      user_agent: request.respond_to?(:user_agent) ? request.user_agent.to_s.first(255) : nil,
      request_id: request.respond_to?(:request_id) ? request.request_id      : nil
    }
    yield
  ensure
    Thread.current[THREAD_KEY] = nil
  end

  def request_context = Thread.current[THREAD_KEY] || {}

  # event:    string like "auth.sign_in", "auth.sign_out", "data.exported"
  # user:     User who performed the action (or nil for anonymous)
  # subject:  optional ActiveRecord that the event relates to
  # payload:  custom data merged into metadata jsonb
  #
  # NOTE: PaperTrail validates that item_type can be constantized, so we always
  # supply a real model class. Subject takes priority; otherwise we fall back
  # to the acting User (auth events log against the user themselves).
  def log!(event:, user: nil, subject: nil, payload: {})
    item_class = subject&.class || user&.class
    item_id    = subject&.id    || user&.id
    return unless item_class && item_id

    metadata = request_context.merge(payload || {}).compact
    PaperTrail::Version.create!(
      item_type:   item_class.name,
      item_id:     item_id,
      event:       event.to_s,
      whodunnit:   user&.id&.to_s,
      created_at:  Time.current,
      metadata:    metadata
    )
  rescue StandardError => e
    Rails.logger.warn("[AuditLogger] failed: #{e.class}: #{e.message}")
  end
end
