class CreateAiRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_runs do |t|
      t.references :job_applicant,    foreign_key: true
      t.references :interview_round,  foreign_key: true
      t.references :user,             null: false, foreign_key: true

      t.string  :kind,           null: false   # analyze_resume / recommend / questions_for / ping
      t.string  :model,          null: false
      t.integer :input_tokens,   default: 0
      t.integer :output_tokens,  default: 0
      t.integer :total_tokens,   default: 0
      t.decimal :cost_usd, precision: 10, scale: 6, default: 0

      t.boolean :success, null: false, default: false
      t.jsonb   :payload, null: false, default: {}
      t.text    :error

      t.timestamps
    end

    add_index :ai_runs, %i[job_applicant_id created_at]
    add_index :ai_runs, %i[interview_round_id created_at]
    add_index :ai_runs, :kind
  end
end
