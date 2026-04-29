class CreateApplicantNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :applicant_notes do |t|
      t.references :job_applicant, null: false, foreign_key: true, index: true
      t.references :author,        null: false, foreign_key: { to_table: :users }, index: true
      t.text    :body, null: false
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :applicant_notes, :discarded_at
  end
end
