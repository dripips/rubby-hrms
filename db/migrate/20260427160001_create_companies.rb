class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string  :name,              null: false
      t.string  :legal_name
      t.string  :code,              limit: 32
      t.string  :inn,               limit: 12
      t.string  :kpp,               limit: 9
      t.string  :country,           limit: 2, default: "RU"
      t.string  :default_currency,  limit: 3, default: "RUB"
      t.string  :default_locale,    limit: 5, default: "ru"
      t.string  :default_time_zone, default: "Moscow"
      t.string  :address
      t.string  :phone
      t.string  :email
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :companies, :code, unique: true, where: "code IS NOT NULL"
    add_index :companies, :inn,  unique: true, where: "inn IS NOT NULL"
    add_index :companies, :discarded_at
  end
end
