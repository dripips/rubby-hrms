class AddDocumentToAiRuns < ActiveRecord::Migration[8.1]
  def change
    add_reference :ai_runs, :document, foreign_key: true
  end
end
