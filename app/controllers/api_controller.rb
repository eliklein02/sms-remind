class ApiController < ApplicationController
    require 'chronic'

    skip_before_action :verify_authenticity_token


    def twilio_webhook
        from_number = params[:From]
        body = params[:Body]
        body_down = body.downcase
        body_first_word = body_down.split(" ")[0]
        case body_first_word
        when "register", "signup"
            u = User.find_or_create_by(phone_number: from_number)
        when "yes"
            u = User.find_by(phone_number: to_e164(from_number))
            return if u.nil?
            u.update(is_opted_in: true)
            send_sms(from_number, "Thank you for opting in to receive messages. Example usage: 'remind me tomorrow morning to pick up my shirts'. Reply STOP to opt out.")
        else
            u = User.find_by(phone_number: to_e164(from_number))
            puts u.inspect
            send_sms(from_number, "You are not registered to receive messages from Remind. Please reply with 'register' to sign up.") and return if u.nil?
            send_sms(from_number, "You have not replied YES to the confirmation message. Please reply YES to continue.") and return if u.is_opted_in === false
            jobs_count = u.jobs_count
            send_sms(from_number, "Exceeded free tier limit of 3 active reminders. Reply UPGRADE to updagrade yout account" ) and return if jobs_count >= 3
            puts u.jobs_count
            ai_parsed = ai_sms_parser(body)
            puts ai_parsed
            time = ai_parsed.split("#")[0]
            subject = ai_parsed.split("#")[1]
            formatted_time = Chronic.parse(time)
            if formatted_time.nil? || formatted_time === ""
                send_sms(from_number, "You did not provide a valid date/time. Please try again.")
                return
            end
            puts formatted_time
            job = u.schedule_reminder(formatted_time, subject)
            puts "Job: #{job}"
        end
        render json: { message: "All Good" }, status: :ok
    end

    def ai_sms_parser(input)
        now = Time.now
        now = now.strftime("%Y-%m-%d (%A) %I:%M:%S %p")
        client = OpenAI::Client.new
        response = client.chat(
          parameters: {
            model: "gpt-4o",
            messages: [
                { role: "user", content: "You are a natural language time parser. You will return the time and subject given to you by a human in the following format: 'yyyy-mm-dd, hh:mm:ss (AM/PM)#subject of the reminder.
                                        You will take the current time, and use the natural language time given to you by the user to return the time in the format I just mentioned.
                                        You will use some logical reasoning to determine the time (ie, if the current time is after midnight, but before 4am, and the user says something 
                                        includig 'tomorrow', or the like, you will return the same day because that is what they mean). You will return ONLY the time in the format I mentioned,
                                        and no more words, only in parentheses, you will return the logic of how you came to that conclusion in 8 words or less.
                                        Here is the current time: #{now}
                                        Here is the user's time: #{input}" }
            ],
            temperature: 0.7
          }
        )
        response.dig("choices", 0, "message", "content")
    end

    def send_sms(to, what)
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

    def test_json
        now = Time.now
        now = now.strftime("%Y-%m-%d (%A) %I:%M:%S %p")
        puts now
        client = OpenAI::Client.new
        response = client.chat(
          parameters: {
            model: "gpt-4o",
            messages: [
              { role: "user", content: "You are a natural language time parser. You will return the time given to you by a human in the followinf format: yyyy-mm-dd, hh:mm:ss (AM/PM).
                                        You will take the current time, and use the natural language time given to you by the user to return the time in the format I just mentioned.
                                        You will use some logical reasoning to determine the time (ie, if the current time is after midnight, but before 4am, and the user says something 
                                        includig 'tomorrow', or the like, you will return the same day because that is what they mean). You will return ONLY the time in the format I mentioned,
                                        and no more words, only in parentheses, you will return the logic of how you came to that conclusion in 8 words or less.
                                        Here is the current time: #{now}
                                        Here is the user's time: in one month and 2 days at 4:30pm" 
                                        }
            ],
            temperature: 0.7
          }
        )
        render json: { message: response.dig("choices", 0, "message", "content"), message2: "All good" }
        # render json: { message: "Success" }
    end

    def do_something
        time = Chronic.parse('in 5 seconds')
        respond_to do |format|
            format.json { render json: { message: "Scheduled reminder for #{time}" } }
        end
    end

    def check_phone_number
        number = to_e164(params[:phone_number])
        puts number
        user = User.find_by(phone_number: number)
        render json: { message: "User not found", user: user } and return if user.nil?
        render json: { message: "User found", user: user }
    end

    def to_e164(pn)
        phone_number = pn
        phone_number.gsub!(/[^0-9]/, '')
        phone_number = "+1#{phone_number[0..2]}-#{phone_number[3..5]}-#{phone_number[6..9]}" if phone_number.length === 10
        phone_number = "+1#{phone_number[1..3]}-#{phone_number[4..6]}-#{phone_number[7..10]}" if phone_number.length === 11
        phone_number
    end
end
