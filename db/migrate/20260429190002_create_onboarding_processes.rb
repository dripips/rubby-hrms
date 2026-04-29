class CreateOnboardingProcesses < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_processes do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :template, foreign_key: { to_table: :process_templates }
      t.references :mentor,   foreign_key: { to_table: :employees }
      t.references :created_by, foreign_key: { to_table: :users }

      t.string   :state, null: false, default: "draft"   # draft|active|completed|cancelled
      t.date     :started_on
      t.date     :target_complete_on
      t.datetime :completed_at

      t.text     :ai_summary               # последняя AI-сводка (welcome / plan / mentor)
      t.datetime :discarded_at, index: true

      t.timestamps
    end

    add_index :onboarding_processes, :state
  end
end
