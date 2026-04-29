class AddEmployeeToAiRuns < ActiveRecord::Migration[8.1]
  def change
    add_reference :ai_runs, :employee, foreign_key: true, index: true
  end
end
