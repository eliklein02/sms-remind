class ReminderJob < ApplicationJob

  # require 'twilio-ruby'

  queue_as :default

  def perform(*args)
    u_id = args[0]
    subject = args[1]
    send_sms(u_id, subject)
  end

  def send_sms(user_id, what)
    u = User.find(user_id)
    to = u.phone_number
    what.strip!
    account_sid = ENV['TWILIO_ACCOUNT_SID']
    auth_token = ENV['TWILIO_AUTH_TOKEN']
    twilio_phone_number = ENV['TWILIO_PHONE_NUMBER']
    @client = Twilio::REST::Client.new(account_sid, auth_token)
    message = @client.messages.create(
        from: twilio_phone_number,
        body: "Reminder: #{what}",
        to: to
    )
    logger.info "Sent SMS to #{to} with message: #{message.body}"
  end
end
