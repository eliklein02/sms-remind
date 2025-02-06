class ReminderJob < ApplicationJob
  require 'twilio-ruby'
  include HelperTools

  queue_as :default

  def perform(*args)
    u_id = args[0]
    subject = args[1]
    u = User.find(u_id)
    phone_number = u.phone_number
    send_sms(phone_number, "Reminder: #{subject}")
  end
end
