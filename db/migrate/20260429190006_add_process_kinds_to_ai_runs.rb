class AddProcessKindsToAiRuns < ActiveRecord::Migration[8.1]
  def change
    add_reference :ai_runs, :onboarding_process,  foreign_key: true
    add_reference :ai_runs, :offboarding_process, foreign_key: true
  end
end
