class AddCustomFieldsToEmployeeAndApplicant < ActiveRecord::Migration[8.1]
  def change
    add_column :employees,      :custom_fields, :jsonb, default: {}
    add_column :job_applicants, :custom_fields, :jsonb, default: {}
  end
end
