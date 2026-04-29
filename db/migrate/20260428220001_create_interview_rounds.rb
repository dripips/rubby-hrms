class CreateInterviewRounds < ActiveRecord::Migration[8.1]
  def change
    create_table :interview_rounds do |t|
      t.references :job_applicant, null: false, foreign_key: true
      t.references :interviewer,   foreign_key: { to_table: :users }
      t.references :created_by,    null: false, foreign_key: { to_table: :users }

      t.string  :kind,    null: false, default: "hr"   # hr/tech/cultural/final
      t.string  :state,   null: false, default: "scheduled"

      t.datetime :scheduled_at, null: false
      t.integer  :duration_minutes, default: 60

      t.string :location
      t.string :meeting_url

      # Самообъясняющий scorecard. Каждый раунд имеет свой набор компетенций,
      # ключи берутся из InterviewRound::COMPETENCY_TEMPLATES[kind].
      # Значения 1..5.
      t.jsonb :competency_scores, null: false, default: {}
      t.integer :overall_score
      t.string  :recommendation              # strong_no/no/maybe/yes/strong_yes

      t.text :notes
      t.text :decision_comment

      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :interview_rounds, :state
    add_index :interview_rounds, :scheduled_at
    add_index :interview_rounds, :discarded_at
  end
end
