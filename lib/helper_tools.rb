module HelperTools
    def send_sms(to, what)
        # user = User.find_by(phone_number: to)
        # return if user.is_opted_in != true
        puts "im in the application helper"
        account_sid = ENV['TWILIO_ACCOUNT_SID']
        auth_token = ENV['TWILIO_AUTH_TOKEN']
        twilio_phone_number = ENV['TWILIO_PHONE_NUMBER']
        @client = Twilio::REST::Client.new(account_sid, auth_token)
        message = @client.messages.create(
            from: twilio_phone_number,
            body: what,
            to: to
        )
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

    def to_e164(phone_number)
        phone_number = phone_number.gsub!(/[^0-9]/, '')
        phone_number = "+1#{phone_number[0..2]}-#{phone_number[3..5]}-#{phone_number[6..9]}" if phone_number.length === 10
        phone_number = "+1#{phone_number[1..3]}-#{phone_number[4..6]}-#{phone_number[7..10]}" if phone_number.length === 11
        phone_number
    end
end
