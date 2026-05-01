class AddCustomFieldsToLeaveRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :leave_requests, :custom_fields, :jsonb, default: {}
  end
end
