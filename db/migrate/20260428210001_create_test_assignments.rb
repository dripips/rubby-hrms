class CreateTestAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :test_assignments do |t|
      t.references :job_applicant, null: false, foreign_key: true, index: true
      t.references :created_by,    null: false, foreign_key: { to_table: :users }, index: true
      t.references :reviewed_by,   foreign_key: { to_table: :users }, index: true

      t.string  :title,       null: false
      t.text    :description
      t.text    :requirements
      t.datetime :deadline
      t.string  :state,       null: false, default: "sent"   # sent / in_progress / submitted / reviewed / cancelled
      t.text    :submission_text
      t.datetime :submitted_at
      t.integer :score             # 0-100
      t.text    :reviewer_notes
      t.datetime :reviewed_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :test_assignments, :state
    add_index :test_assignments, :deadline
    add_index :test_assignments, :discarded_at
  end
end
