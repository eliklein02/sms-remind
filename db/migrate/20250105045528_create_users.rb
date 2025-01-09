class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.timestamps
      t.string :name
      t.string :phone_number
      t.boolean :is_opted_in
    end
  end
end
