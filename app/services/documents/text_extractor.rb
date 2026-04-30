# Извлекает текст из файла документа (PDF или image).
# PDF → pdf-reader (pure Ruby, без бинарников, работает с text-based PDFs).
# Image → rtesseract (требует Tesseract бинарник; на Windows локально может
# отсутствовать — в таком случае возвращаем пустую строку, не падаем).
#
# Returns: { text: "...", method: "pdf-reader|ocr|none", error: nil|String }
module Documents
  class TextExtractor
    MIN_USEFUL_TEXT_LENGTH = 50  # если PDF дал меньше — считаем что это скан

    def self.call(blob)
      new(blob).call
    end

    def initialize(blob)
      @blob = blob
    end

    def call
      return empty_result("no_blob") unless @blob
      return empty_result("blob_not_attached") unless @blob.respond_to?(:download)

      content_type = @blob.content_type.to_s.downcase

      case content_type
      when "application/pdf"
        extract_from_pdf
      when /\Aimage\//
        extract_from_image
      else
        empty_result("unsupported_content_type:#{content_type}")
      end
    rescue StandardError => e
      Rails.logger.warn("[TextExtractor] #{e.class}: #{e.message}")
      empty_result(e.message.first(200))
    end

    private

    def extract_from_pdf
      text = ""
      with_local_file do |path|
        require "pdf-reader"
        reader = PDF::Reader.new(path)
        text = reader.pages.map(&:text).join("\n\n").strip
      end

      if text.length >= MIN_USEFUL_TEXT_LENGTH
        { text: text, method: "pdf-reader", error: nil }
      else
        # Скан — пробуем OCR
        ocr_result = extract_from_image_pdf
        ocr_result[:method] = "ocr-pdf" if ocr_result[:text].present?
        ocr_result
      end
    end

    def extract_from_image
      with_local_file do |path|
        text = run_tesseract(path)
        return { text: text, method: "ocr", error: nil }
      end
    end

    def extract_from_image_pdf
      # Конвертация PDF → image для OCR требует pdftoppm/poppler.
      # На Windows локально может не быть — тогда возвращаем пусто, и пользователь
      # может в Settings/документе указать, что разбор недоступен.
      empty_result("ocr_pdf_not_implemented_locally")
    end

    def run_tesseract(image_path)
      require "rtesseract"
      RTesseract.new(image_path, lang: "rus+eng").to_s.strip
    rescue StandardError => e
      Rails.logger.warn("[TextExtractor#run_tesseract] #{e.class}: #{e.message}")
      ""
    end

    def with_local_file
      tempfile = Tempfile.new([ "doc_", File.extname(@blob.filename.to_s) ], binmode: true)
      tempfile.write(@blob.download)
      tempfile.flush
      yield tempfile.path
    ensure
      tempfile&.close
      tempfile&.unlink
    end

    def empty_result(error)
      { text: "", method: "none", error: error }
    end
  end
end
