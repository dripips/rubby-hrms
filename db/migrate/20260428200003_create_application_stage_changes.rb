class CreateApplicationStageChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :application_stage_changes do |t|
      t.references :job_applicant, null: false, foreign_key: true, index: true
      t.references :user,          null: false, foreign_key: true, index: true
      t.string  :from_stage
      t.string  :to_stage,    null: false
      t.text    :comment
      t.datetime :changed_at, null: false

      t.timestamps
    end

    add_index :application_stage_changes, :changed_at
  end
end
