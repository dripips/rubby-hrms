class AddConsentsToJobApplicants < ActiveRecord::Migration[8.0]
  def change
    add_column :job_applicants, :consents, :jsonb, default: {}, null: false
    add_index  :job_applicants, :consents, using: :gin
  end
end
