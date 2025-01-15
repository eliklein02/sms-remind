class ReminderCallJob < ApplicationJob
  queue_as :default

  def perform(*args)
    u = args[0]
    about = args[1]
    make_phone_call(u, about)
  end


  def make_phone_call(user_id, about)
    u = User.find(user_id)
    account_sid = ENV['TWILIO_ACCOUNT_SID']
    auth_token = ENV['TWILIO_AUTH_TOKEN']
    @client = Twilio::REST::Client.new(account_sid, auth_token)

    call = @client
        .api
        .v2010
        .calls
        .create(
            twiml: "<Response>
                      <Pause length = '1' />
                      <Say>This is your reminder about #{about}</Say>
                    </Response>",
            to: u.phone_number,
            from: ENV["TWILIO_PHONE_NUMBER"]
        )

    puts call.sid
end
end
