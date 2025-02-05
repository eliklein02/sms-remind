class CreateEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :events do |t|
      t.timestamps
      t.string :user_phone_number
      t.string :reminder_type
      t.string :location
    end
  end
end
