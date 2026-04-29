class CreateOffboardingProcesses < ActiveRecord::Migration[8.1]
  def change
    create_table :offboarding_processes do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :template, foreign_key: { to_table: :process_templates }
      t.references :created_by, foreign_key: { to_table: :users }

      t.string  :state,  null: false, default: "draft"   # draft|active|completed|cancelled
      t.string  :reason, null: false, default: "voluntary" # voluntary|involuntary|retirement|contract_end
      t.date    :last_day
      t.datetime :completed_at

      t.integer :exit_risk_score                      # 0..100, заполняет AI агент exit_risk_brief
      t.jsonb   :knowledge_areas, default: []         # AI knowledge_transfer_plan
      t.text    :ai_summary

      t.datetime :discarded_at, index: true
      t.timestamps
    end

    add_index :offboarding_processes, :state
  end
end
