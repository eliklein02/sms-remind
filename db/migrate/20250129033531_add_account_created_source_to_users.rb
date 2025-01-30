class AddAccountCreatedSourceToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :account_source, :string
  end
end
