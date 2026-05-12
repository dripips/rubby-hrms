class AddTargetableToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :targetable_type, :string
    add_column :conversations, :targetable_id,   :bigint
    add_index  :conversations, [ :targetable_type, :targetable_id ], unique: true,
                                where: "targetable_type IS NOT NULL",
                                name: "idx_conversations_on_targetable_unique"
  end
end
