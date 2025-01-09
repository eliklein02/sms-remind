class AddUserIdToJobs < ActiveRecord::Migration[7.2]
  def change
    add_column :delayed_jobs, :user_id, :integer
  end
end
