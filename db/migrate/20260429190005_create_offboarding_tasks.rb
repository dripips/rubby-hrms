class CreateOffboardingTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :offboarding_tasks do |t|
      t.references :offboarding_process, null: false, foreign_key: true, index: { name: "idx_off_tasks_process" }
      t.references :assignee, foreign_key: { to_table: :users }

      t.string  :title, null: false
      t.text    :description
      t.string  :kind, null: false, default: "general"   # kt_session|access_revoke|equipment_return|exit_interview|farewell|paperwork|general
      t.string  :state, null: false, default: "pending"  # pending|in_progress|done|skipped
      t.date    :due_on
      t.integer :position, null: false, default: 0
      t.boolean :ai_generated, null: false, default: false

      t.datetime :completed_at

      t.timestamps
    end

    add_index :offboarding_tasks, :state
    add_index :offboarding_tasks, :due_on
  end
end
