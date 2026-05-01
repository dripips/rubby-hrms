class AddKindToDictionaries < ActiveRecord::Migration[8.1]
  def change
    # lookup       — традиционные справочники-списки (источники, причины, и т.п.)
    # field_schema — определяет дополнительные поля для другой сущности.
    #                code = "<TargetModel>:<scope>" (e.g. "DocumentType:5", "Employee:default")
    add_column :dictionaries, :kind, :string, default: "lookup", null: false
    add_index  :dictionaries, [ :company_id, :kind ]
  end
end
