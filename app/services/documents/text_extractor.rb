# Извлекает текст из файла документа (PDF или image).
# PDF → pdf-reader (pure Ruby, без бинарников, работает с text-based PDFs).
# Image → rtesseract (требует Tesseract бинарник; на Windows локально может
# отсутствовать — в таком случае возвращаем пустую строку, не падаем).
#
# Returns: { text: "...", method: "pdf-reader|ocr|none", error: nil|String }
require "open3"
require "tmpdir"

module Documents
  class TextExtractor
    MIN_USEFUL_TEXT_LENGTH = 50  # если PDF дал меньше — считаем что это скан

    @poppler_available = nil  # singleton-кэш на процесс

    class << self
      attr_accessor :poppler_available
    end

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
    rescue StandardError, ScriptError => e
      Rails.logger.warn("[TextExtractor] #{e.class}: #{e.message}")
      empty_result("#{e.class.name.demodulize}: #{e.message.first(160)}")
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
        text, error = run_tesseract(path)
        return { text: text, method: "ocr", error: nil } if text.present?

        empty_result(error || "ocr_empty_result")
      end
    end

    # Скан-PDF — конвертируем pdftoppm'ом каждую страницу в PNG,
    # прогоняем через Tesseract, объединяем текст.
    #
    # Зависимости (есть в Dockerfile, на Windows локально могут отсутствовать):
    #   • pdftoppm (из poppler-utils)
    #   • tesseract + языковые модели (rus, eng)
    #
    # Возвращает пустой результат если poppler не установлен — это валидная
    # ситуация для dev-окружения без OCR-инструментов.
    def extract_from_image_pdf
      return empty_result("poppler_not_installed") unless poppler_available?

      with_local_file do |pdf_path|
        Dir.mktmpdir("hrms_ocr_") do |tmpdir|
          prefix = File.join(tmpdir, "page")
          stdout, stderr, status = Open3.capture3(
            "pdftoppm", "-r", "300", "-png", pdf_path, prefix
          )

          unless status.success?
            Rails.logger.warn("[TextExtractor pdftoppm] #{stderr.first(200)}")
            return empty_result("pdftoppm_failed:#{stderr.first(60)}")
          end

          pages = Dir.glob(File.join(tmpdir, "page-*.png")).sort
          return empty_result("pdftoppm_no_pages") if pages.empty?

          parts = []
          pages.each do |png|
            text, err = run_tesseract(png)
            if text.present?
              parts << text
            elsif err
              Rails.logger.info("[TextExtractor ocr-pdf page] #{err}")
            end
          end

          combined = parts.join("\n\n--- page break ---\n\n").strip
          if combined.present?
            { text: combined, method: "ocr-pdf", error: nil }
          else
            empty_result("ocr_yielded_empty")
          end
        end
      end
    rescue StandardError => e
      Rails.logger.warn("[TextExtractor extract_from_image_pdf] #{e.class}: #{e.message}")
      empty_result("ocr_pdf_failed:#{e.class.name.demodulize}")
    end

    # pdftoppm доступен? Кэшируем результат на класс — не меняется в runtime.
    def poppler_available?
      cached = self.class.poppler_available
      return cached unless cached.nil?

      result = begin
        _stdout, _stderr, status = Open3.capture3("pdftoppm", "-v")
        status.success? || status.exitstatus == 99
      rescue Errno::ENOENT, StandardError
        false
      end
      self.class.poppler_available = result
      result
    end

    # Returns [text, error]. На Windows без установленного Tesseract.exe сюда
    # прилетает LoadError (gem не загрузился из-за бинарника) или RTesseract::*.
    def run_tesseract(image_path)
      require "rtesseract"
      text = RTesseract.new(image_path, lang: "rus+eng").to_s.strip
      [ text, nil ]
    rescue LoadError => e
      Rails.logger.warn("[TextExtractor#run_tesseract] LoadError: #{e.message}")
      [ nil, "tesseract_unavailable" ]
    rescue StandardError => e
      Rails.logger.warn("[TextExtractor#run_tesseract] #{e.class}: #{e.message}")
      [ nil, "ocr_failed:#{e.class.name.demodulize}" ]
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
