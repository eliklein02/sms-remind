class AddOtpTmpToUser < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :tmp_otp, :string
  end
end
