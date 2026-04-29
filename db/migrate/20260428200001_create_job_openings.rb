class CreateJobOpenings < ActiveRecord::Migration[8.1]
  def change
    create_table :job_openings do |t|
      t.references :company,    null: false, foreign_key: true, index: true
      t.references :department, foreign_key: true, index: true
      t.references :position,   foreign_key: true, index: true
      t.references :grade,      foreign_key: true, index: true
      t.references :owner,      foreign_key: { to_table: :users }, index: true

      t.string  :title,           null: false
      t.string  :code,            limit: 32
      t.integer :openings_count,  null: false, default: 1
      t.integer :state,           null: false, default: 0  # draft/open/on_hold/closed
      t.text    :description
      t.text    :requirements
      t.text    :nice_to_have

      t.decimal :salary_from, precision: 12, scale: 2
      t.decimal :salary_to,   precision: 12, scale: 2
      t.string  :currency, limit: 3, default: "RUB"
      t.string  :employment_type, default: "full_time"

      t.date    :published_at
      t.date    :closes_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :job_openings, [:company_id, :code], unique: true, where: "code IS NOT NULL"
    add_index :job_openings, :state
    add_index :job_openings, :discarded_at
  end
end
