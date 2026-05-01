class AddDictionaryToAiRuns < ActiveRecord::Migration[8.1]
  def change
    add_reference :ai_runs, :dictionary, foreign_key: true
  end
end
