class AddDefaultOptedIn < ActiveRecord::Migration[7.2]
  def change
    change_column_default :users, :is_opted_in, from: nil, to: false
  end
end
