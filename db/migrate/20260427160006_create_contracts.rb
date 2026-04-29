class CreateContracts < ActiveRecord::Migration[8.1]
  def change
    create_table :contracts do |t|
      t.references :employee, null: false, foreign_key: true, index: true
      t.string  :number, limit: 64
      t.integer :kind, null: false, default: 0  # 0 permanent, 1 fixed_term, 2 service_agreement (ГПХ), 3 internship
      t.date    :started_at, null: false
      t.date    :ended_at
      t.decimal :salary, precision: 12, scale: 2
      t.string  :currency, limit: 3, default: "RUB"
      t.decimal :working_rate, precision: 4, scale: 2, default: 1.0  # 1.0 = full-time
      t.date    :signed_at
      t.boolean :active, null: false, default: true
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :contracts, [:employee_id, :active]
    add_index :contracts, :started_at
  end
end
