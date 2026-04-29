class CreateOnboardingTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_tasks do |t|
      t.references :onboarding_process, null: false, foreign_key: true, index: { name: "idx_ob_tasks_process" }
      t.references :assignee, foreign_key: { to_table: :users }

      t.string  :title,       null: false
      t.text    :description
      t.string  :kind, null: false, default: "general"   # paperwork|equipment|access|training|intro|checkin|general
      t.string  :state, null: false, default: "pending"  # pending|in_progress|done|skipped
      t.date    :due_on
      t.integer :position, null: false, default: 0
      t.boolean :ai_generated, null: false, default: false

      t.datetime :completed_at

      t.timestamps
    end

    add_index :onboarding_tasks, :state
    add_index :onboarding_tasks, :due_on
  end
end
