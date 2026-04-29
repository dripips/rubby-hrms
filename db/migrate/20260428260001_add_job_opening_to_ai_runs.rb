class AddJobOpeningToAiRuns < ActiveRecord::Migration[8.1]
  def change
    add_reference :ai_runs, :job_opening, foreign_key: true
  end
end
