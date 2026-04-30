# Авто-разбор документа: pdf-reader для PDF / rtesseract для image →
# regex extractor по document_type.extractor_kind → extracted_data:jsonb.
# AI используется ТОЛЬКО как fallback в Phase 4, и только на уже
# извлечённый текст (не на сырой документ).
class DocumentExtractionJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.kept.find_by(id: document_id) or return
    return unless document.file.attached?

    # Заглушка для Phase 1-2 — реальная логика в Phase 3.
    document.update!(
      extraction_method: "none",
      extracted_at:      Time.current
    )
  end
end
