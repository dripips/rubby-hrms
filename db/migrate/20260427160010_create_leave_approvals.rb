class CreateLeaveApprovals < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_approvals do |t|
      t.references :leave_request, null: false, foreign_key: true, index: true
      t.references :approver,      null: false, foreign_key: { to_table: :users }, index: true
      t.integer  :step,     null: false, default: 0  # 0 manager, 1 hr
      t.integer  :decision, null: false, default: 0  # 0 pending, 1 approved, 2 rejected
      t.text     :comment
      t.datetime :decided_at

      t.timestamps
    end

    add_index :leave_approvals, [:leave_request_id, :step], unique: true, name: "leave_approval_step_uniq"
  end
end
