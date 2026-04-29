class AddMetadataAndRevertToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :versions, :metadata,    :jsonb,    default: {}, null: false
    add_column :versions, :reverted_at, :datetime
    add_column :versions, :reverted_by, :string
    add_index  :versions, :event
    add_index  :versions, :whodunnit
    add_index  :versions, :created_at
  end
end
