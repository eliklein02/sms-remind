class AddTimeZoneToUser < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :time_zone, :string
  end
end
