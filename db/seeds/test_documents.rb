# Локальные тестовые документы — генерируем PDF с реальным текстовым слоем
# (через Prawn) и прикрепляем к Document'ам для первого Employee. На Windows
# без Tesseract это единственный способ протестировать happy-path: pdf-reader
# извлекает текст без OCR, дальше gem-extractor + AI работают полноценно.
#
# Запуск:  bin/rails runner db/seeds/test_documents.rb
require "prawn"
require "fileutils"

EMP    = Employee.kept.working.order(:id).first or abort("Нет сотрудников — создай хоть одного")
USER   = User.where(role: %w[hr superadmin]).first or abort("Нет HR-юзера")
TYPES  = DocumentType.where.not(extractor_kind: [ nil, "free" ]).index_by(&:extractor_kind)

def font_path
  candidates = [
    "C:/Windows/Fonts/arial.ttf",
    "C:/Windows/Fonts/Arial.ttf",
    "C:/Windows/Fonts/calibri.ttf"
  ]
  candidates.find { |p| File.exist?(p) } or abort("Не нашёл TTF-шрифт с кириллицей")
end

def pdf_to_io(filename, &block)
  Prawn::Document.new(page_size: "A4", margin: 60) do |pdf|
    pdf.font_families.update("DejaVu" => { normal: font_path, bold: font_path })
    pdf.font "DejaVu"
    pdf.font_size 11
    pdf.instance_exec(&block)
  end.render
end

def build(extractor_kind, title, body)
  type = TYPES[extractor_kind] or (puts "  ! пропустил #{extractor_kind} — нет DocumentType"; return)

  pdf_bytes = pdf_to_io(title) do
    text title.upcase, size: 14, style: :bold
    move_down 10
    text body
  end

  doc = Document.kept.find_or_initialize_by(documentable: EMP, document_type: type, title: title)
  doc.assign_attributes(state: "active", confidentiality: "internal", created_by: USER, extracted_data: {})
  doc.save!

  io = StringIO.new(pdf_bytes)
  doc.file.attach(io: io, filename: "#{title.parameterize}.pdf", content_type: "application/pdf")
  puts "  ✓ #{extractor_kind}: Document##{doc.id} — #{title}"
end

puts "Сотрудник: #{EMP.full_name} (id=#{EMP.id})"
puts "Доступные extractor_kind: #{TYPES.keys.join(", ")}"

build "passport", "Паспорт РФ — тестовый", <<~TXT
  ПАСПОРТ ГРАЖДАНИНА РОССИЙСКОЙ ФЕДЕРАЦИИ

  Серия 4520 номер 123456
  Дата выдачи: 12.03.2020
  Кем выдан: ОУФМС России по гор. Москве по району Хамовники
  Код подразделения: 770-024

  Фамилия: Бобков
  Имя: Вадим
  Отчество: Александрович
  Пол: мужской
  Дата рождения: 15.07.1988
  Место рождения: гор. Москва
TXT

build "diploma", "Диплом ВУЗа — тестовый", <<~TXT
  ДИПЛОМ О ВЫСШЕМ ОБРАЗОВАНИИ

  ВБА № 1234567
  Дата выдачи: 25.06.2010

  Настоящий диплом выдан Бобкову Вадиму Александровичу в том,
  что он в 2005 году поступил в Московский Государственный Университет
  имени М.В. Ломоносова и в 2010 году окончил полный курс.

  Специальность: Прикладная математика и информатика
  Квалификация: Математик, системный программист
  Степень: Магистр
TXT

build "contract", "Трудовой договор — тестовый", <<~TXT
  ТРУДОВОЙ ДОГОВОР № ТД-2024/0042

  г. Москва                                          15 января 2024 г.

  ООО «Тест-Компания», в лице генерального директора Иванова И.И.,
  именуемое в дальнейшем «Работодатель», и Бобков Вадим Александрович,
  именуемый в дальнейшем «Работник», заключили настоящий договор.

  1. Работник принимается на должность: Senior Software Engineer
  2. Дата начала работы: 01.02.2024
  3. Заработная плата: 350 000 рублей
  4. Срок действия договора: бессрочный
TXT

build "nda", "NDA — тестовое соглашение", <<~TXT
  СОГЛАШЕНИЕ О НЕРАЗГЛАШЕНИИ

  № NDA-2024-007 от 01 февраля 2024 г.

  Стороны:
    ООО «Тест-Компания» (Раскрывающая сторона)
    Бобков Вадим Александрович (Получающая сторона)

  Срок действия: 3 года с даты подписания.
  Действует до: 01.02.2027

  Получающая сторона обязуется не разглашать конфиденциальную
  информацию, ставшую ей известной в связи с трудовыми обязанностями.
TXT

puts "\nГотово. Открой /ru/documents и тыкай кнопки на одном из созданных документов."
