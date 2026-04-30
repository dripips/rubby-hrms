class ExtendDocumentsForAi < ActiveRecord::Migration[8.1]
  def change
    change_table :documents do |t|
      t.string   :state,             null: false, default: "active"  # active/expired/revoked/draft
      t.text     :summary                                              # AI-generated краткое содержание
      t.jsonb    :extracted_data,    default: {}                       # structured data: passport_number, employer, etc.
      t.string   :extraction_method                                    # gem/ai/manual/none
      t.datetime :extracted_at
      t.string   :confidentiality,   null: false, default: "internal" # public/internal/confidential
      t.string   :title                                                # человекочитаемое имя ("Паспорт РФ")
      t.references :created_by, foreign_key: { to_table: :users }
    end

    add_index :documents, :state
    add_index :documents, :confidentiality

    change_table :document_types do |t|
      t.string :extractor_kind                                          # passport/snils/inn/contract/diploma/free
      t.text   :description
      t.string :icon                                                    # emoji или класс иконки
      t.integer :default_validity_months                                # сколько месяцев по умолчанию валиден
    end

    add_index :document_types, :extractor_kind
  end
end
