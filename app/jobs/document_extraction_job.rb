# Авто-разбор документа: TextExtractor → ExtractorRegistry → extracted_data.
# Шаги:
#   1. Извлечь текст из файла (PDF через pdf-reader, image через rtesseract OCR)
#   2. Найти extractor для document_type.extractor_kind
#   3. Применить extractor к тексту → hash с найденными полями
#   4. Сохранить в document.extracted_data, обновить extraction_method
#
# Если text-extraction вернул пусто — extraction_method = "none" + лог ошибки.
# AI-fallback (Phase 4) запускается отдельной командой пользователя при необходимости.
class DocumentExtractionJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 2

  def perform(document_id)
    document = Document.kept.find_by(id: document_id) or return
    return unless document.file.attached?

    extractor_kind = document.document_type&.extractor_kind
    return mark_skipped(document, "no_extractor_kind") if extractor_kind.blank? || extractor_kind == "free"

    text_result = Documents::TextExtractor.call(document.file.blob)
    text        = text_result[:text]

    if text.blank?
      mark_failed(document, text_result[:error] || "empty_text")
      return
    end

    extractor_class = Documents::ExtractorRegistry.for(extractor_kind)
    return mark_skipped(document, "extractor_not_implemented:#{extractor_kind}") unless extractor_class

    fields = extractor_class.call(text)

    apply_fields_to_document(document, fields)
    document.update!(
      extracted_data:    document.extracted_data.to_h.merge(fields),
      extraction_method: "gem",
      extracted_at:      Time.current
    )

    Rails.logger.info("[DocumentExtractionJob] #{document_id} #{extractor_kind}: #{fields.keys.size} fields")
  end

  private

  # Если extractor нашёл number/issued_at/expires_at — сразу прокинем в основные
  # поля Document (они отдельно от extracted_data jsonb для удобства фильтров).
  def apply_fields_to_document(document, fields)
    updates = {}
    updates[:number]    = fields["number"]                  if fields["number"].present?    && document.number.blank?
    updates[:issuer]    = fields["issuer"]                  if fields["issuer"].present?    && document.issuer.blank?
    updates[:issued_at] = parse_date(fields["issued_at"])   if fields["issued_at"].present? && document.issued_at.blank?

    expires = fields["expires_at"] || fields["valid_until"]
    updates[:expires_at] = parse_date(expires) if expires.present? && document.expires_at.blank?

    document.assign_attributes(updates) if updates.any?
  end

  def parse_date(value)
    return value if value.is_a?(Date)
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def mark_skipped(document, reason)
    document.update_columns(extraction_method: "none", extracted_at: Time.current)
    Rails.logger.info("[DocumentExtractionJob] #{document.id}: skipped (#{reason})")
  end

  def mark_failed(document, reason)
    document.update_columns(extraction_method: "none", extracted_at: Time.current)
    Rails.logger.warn("[DocumentExtractionJob] #{document.id}: failed (#{reason})")
  end
end
