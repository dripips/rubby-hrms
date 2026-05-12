class AddSubdomainToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :subdomain, :string
    # unique партиал-индекс — subdomain опциональный (nil допустим для
    # single-tenant inst'ов), но если задан — должен быть уникальным.
    add_index  :companies, :subdomain, unique: true,
                                       where: "subdomain IS NOT NULL"
  end
end
