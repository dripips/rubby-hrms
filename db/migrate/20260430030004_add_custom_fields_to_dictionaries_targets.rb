class AddCustomFieldsToDictionariesTargets < ActiveRecord::Migration[8.1]
  def change
    add_column :departments, :custom_fields, :jsonb, default: {}
    add_column :positions,   :custom_fields, :jsonb, default: {}
    add_column :leave_types, :custom_fields, :jsonb, default: {}
  end
end
