class AddRunAtToEvent < ActiveRecord::Migration[7.2]
  def change
    add_column :events, :run_at, :string
  end
end
