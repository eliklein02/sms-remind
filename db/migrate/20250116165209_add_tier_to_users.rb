class AddTierToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :tier, :integer, default: 0
  end
end
