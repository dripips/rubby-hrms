class CreateLeaveRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_requests do |t|
      t.references :employee,   null: false, foreign_key: true, index: true
      t.references :leave_type, null: false, foreign_key: true, index: true
      t.date    :started_on, null: false
      t.date    :ended_on,   null: false
      t.decimal :days, precision: 6, scale: 2, null: false
      t.text    :reason
      t.string  :state, null: false, default: "draft", limit: 32  # aasm
      t.datetime :applied_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :leave_requests, :state
    add_index :leave_requests, [:started_on, :ended_on]
    add_index :leave_requests, :discarded_at
  end
end
