class AddHrFieldsToEmployees < ActiveRecord::Migration[8.1]
  def change
    change_table :employees do |t|
      t.references :gender_ref,            foreign_key: { to_table: :genders }, index: true
      t.string  :marital_status, limit: 32     # single, married, divorced, widowed, partnership
      t.string  :emergency_contact_name
      t.string  :emergency_contact_phone
      t.string  :emergency_contact_relation, limit: 64
      t.string  :shirt_size,                 limit: 16
      t.text    :dietary_restrictions
      t.text    :hobbies
      t.string  :preferred_language,         limit: 8
      t.boolean :has_disability,             null: false, default: false
      t.text    :special_needs
      t.string  :tax_id,                     limit: 32  # ИНН
      t.string  :insurance_id,               limit: 32  # СНИЛС
      t.string  :passport_number,            limit: 32
      t.date    :passport_issued_at
      t.string  :passport_issued_by
      t.string  :native_city
      t.string  :education_level,            limit: 64
      t.string  :education_institution
    end
  end
end
