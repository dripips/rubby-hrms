class CreateJobApplicants < ActiveRecord::Migration[8.1]
  def change
    create_table :job_applicants do |t|
      t.references :company,     null: false, foreign_key: true, index: true
      t.references :job_opening, foreign_key: true, index: true   # nullable: talent pool
      t.references :owner,       foreign_key: { to_table: :users }, index: true

      t.string  :first_name, null: false
      t.string  :last_name,  null: false
      t.string  :email
      t.string  :phone
      t.string  :location
      t.string  :current_company
      t.string  :current_position
      t.integer :years_of_experience

      t.decimal :expected_salary, precision: 12, scale: 2
      t.string  :currency, limit: 3, default: "RUB"

      t.string  :portfolio_url
      t.string  :linkedin_url
      t.string  :github_url
      t.string  :telegram

      t.string  :source, null: false, default: "manual"
      t.jsonb   :source_meta, default: {}

      t.string  :stage, null: false, default: "applied"
      t.integer :overall_score
      t.text    :summary

      t.datetime :applied_at, null: false
      t.datetime :stage_changed_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :job_applicants, :stage
    add_index :job_applicants, :source
    add_index :job_applicants, :applied_at
    add_index :job_applicants, :discarded_at
    add_index :job_applicants, [:last_name, :first_name]
    add_index :job_applicants, :email
    add_index :job_applicants, :source_meta, using: :gin
  end
end
