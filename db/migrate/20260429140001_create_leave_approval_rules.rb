class CreateLeaveApprovalRules < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_approval_rules do |t|
      t.references :company,       null: false, foreign_key: true, index: true
      t.references :leave_type,    null: true,  foreign_key: true, index: true
      t.references :department,    null: true,  foreign_key: true, index: true

      t.string  :name,             null: false
      t.text    :description

      # Day-range bounds (inclusive). nil = unbounded.
      t.integer :min_days
      t.integer :max_days

      # Optional grade filter (e.g. only senior+ → CEO step).
      t.references :min_grade,     null: true,  foreign_key: { to_table: :grades }, index: true

      # If true, the engine returns an empty chain → request auto-approved.
      t.boolean :auto_approve,     null: false, default: false

      # Ordered approval steps as JSONB array of step descriptors:
      #   [{ "kind":"role", "value":"manager" },
      #    { "kind":"role", "value":"hr" },
      #    { "kind":"role", "value":"ceo" },
      #    { "kind":"role", "value":"department_head" },
      #    { "kind":"user", "value":17 }]
      t.jsonb   :approval_chain,   null: false, default: []

      # Lower number = higher priority; first match wins.
      t.integer :priority,         null: false, default: 100
      t.boolean :active,           null: false, default: true
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :leave_approval_rules, %i[company_id priority]
    add_index :leave_approval_rules, :discarded_at
  end
end
