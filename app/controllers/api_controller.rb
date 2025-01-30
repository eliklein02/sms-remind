class ApiController < ApplicationController
    require 'chronic'
    require 'nokogiri'
    require 'twilio-ruby'
    require 'net/http'



    skip_before_action :verify_authenticity_token


    def twilio_webhook
        from_number = params[:From]
        body = params[:Body]
        body_down = body.downcase
        body_first_word = body_down.split(" ")[0]
        case body_first_word
        when "register", "signup"
            u = User.find_or_create_by(phone_number: to_e164(from_number))
        when "finance"
            ai_parsed = ai_elimelech(body)
            send_sms(from_number, ai_parsed)
        when "cancel"
            job_id = body_down.split(" ")[1]
            job = Delayed::Job.find(job_id)
            return if job.nil?
            sender = User.find_by(phone_number: to_e164(from_number))
            job_user = User.find(job.user_id)
            send_sms(from_number, "Nice try :)") and return if job_user.id != sender.id
            job.destroy
            send_sms(from_number, "Reminder has been successfully cancelled.")
        when "word"
            word = body.split(" ")[1]
            defiinition = get_definition(word)
            send_sms(from_number, defiinition)
        else
            handle_else(from_number, body)
        end
        render json: { message: "All Good" }, status: :ok
    end

    def ai_sms_parser(input)
        now = Time.now
        now = now.strftime("%Y-%m-%d (%A) %I:%M:%S %p, %Z")
        client = OpenAI::Client.new
        response = client.chat(
          parameters: {
            model: "gpt-4o",
            messages: [
                { role: "user", content: "You are a natural language time parser. You will return the time and subject and type of reminder given to you by a human in the following format in eastern standar time: 'yyyy-mm-dd, hh:mm:ss (AM/PM)#subject of the reminder#type of reminder.
                                        You will take the current time, and use the natural language time given to you by the user to return the time in the format I just mentioned.
                                        If no time is provided, and there is only a subject, you will return the time as one hour from now.
                                        You will use some logical reasoning to determine the time (ie, if the current time is after midnight, but before 4am, and the user says something
                                        including 'tomorrow', or the like, you will return the date as the same day because that is what they mean.
                                        Or another example, if the user says a specific time, you will return the next instance of that time on the clock, so if now is 1pm and they say 1 oclock that means 1am and so forth, unless of course specified otherwise.)
                                        You will return ONLY the time in the format I mentioned, and no more words.
                                        Seconds are also valid, they might say in a minute and 30 seconds, and you will return the current time plus 1 minute and 30 seconds and so forth for other time increments.
                                        You will also return the subject with correct capitalization and corrected spelling errors after the # like we discussed.
                                        As for the third section, the type, by default you will return as 'sms' unless the user specifies you to call as the reminder type, (NOT IF THE SUBJECT INCLUDES A PHONE CALL AS WHAT THEY NEED TO BE REMINDED ABOUT) in which case you will return 'voice'.
                                        Here is the current time: #{now}
                                        Here is the user's time: #{input}" }
            ],
            temperature: 0.7
          }
        )
        response.dig("choices", 0, "message", "content")
    end

    def ai_sms_parser_voice(input)
        now = Time.now
        now = now.strftime("%Y-%m-%d (%A) %I:%M:%S %p, %Z")
        client = OpenAI::Client.new
        response = client.chat(
          parameters: {
            model: "gpt-4o",
            messages: [
                { role: "user", content: "You are a natural language time parser. You will return the time and subject and type of reminder given to you by a human in the following format in eastern standar time: 'yyyy-mm-dd, hh:mm:ss (AM/PM)#subject of the reminder#type of reminder.
                                        You will take the current time, and use the natural language time given to you by the user to return the time in the format I just mentioned.
                                        If no time is provided, and there is only a subject, you will return the time as one hour from now.
                                        You will use some logical reasoning to determine the time (ie, if the current time is after midnight, but before 4am, and the user says something
                                        including 'tomorrow', or the like, you will return the date as the same day because that is what they mean.
                                        Or another example, if the user says a specific time, you will return the next instance of that time on the clock, so if now is 1pm and they say 1 oclock that means 1am and so forth, unless of course specified otherwise.)
                                        You will return ONLY the time in the format I mentioned, and no more words.
                                        Seconds are also valid, they might say in a minute and 30 seconds, and you will return the current time plus 1 minute and 30 seconds and so forth for other time increments.
                                        You will also return the subject with correct capitalization and corrected spelling errors after the # like we discussed.
                                        As for the third section, the type, by default you will return as 'voice' unless the user specifies you to call as the reminder type, (NOT IF THE SUBJECT INCLUDES A PHONE CALL AS WHAT THEY NEED TO BE REMINDED ABOUT) in which case you will return 'sms'.
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

    def ai_elimelech(input)
        input = input.split(" ")
        input = input[1..-1].join(" ")
        client = OpenAI::Client.new
        response = client.chat(
          parameters: {
            model: "gpt-4o",
            messages: [
                { role: "user", content: "You are a finance expert that answers to the best of your abilities only about finance. Og course no provocative questions are to be answered, even to high standards. You in no circumstances answer about anything other than finances. Never. You discuss concepts and strategies in finance and the like, but if it looks like the question isnt related to fincance you do not answer. You will answer the following question: #{input}" }
            ],
            temperature: 0.7
          }
        )
        response.dig("choices", 0, "message", "content")
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

    def get_definition(word)
        url = "https://www.dictionaryapi.com/api/v3/references/collegiate/json/#{word}?key=#{ENV['DICTIONARY_API_KEY']}"
        uri = URI(url)
        response = Net::HTTP.get(uri)
        response = JSON.parse(response)
        definition = response[0]["shortdef"]
        return definition
    end

    def do_something
        time = Chronic.parse('in 5 seconds')
        respond_to do |format|
            format.json { render json: { message: "Scheduled reminder for #{time}" } }
        end
    end

    def to_e164(phone_number)
        phone_number.gsub!(/[^0-9]/, '')
        phone_number = "+1#{phone_number[0..2]}-#{phone_number[3..5]}-#{phone_number[6..9]}" if phone_number.length === 10
        phone_number = "+1#{phone_number[1..3]}-#{phone_number[4..6]}-#{phone_number[7..10]}" if phone_number.length === 11
        phone_number
    end

    def handle_else(from_number, body)
        u = User.find_by(phone_number: to_e164(from_number))
        send_sms(from_number, "You are not registered to receive messages from Remind. Please reply with 'register' to sign up.") and return if u.nil?
        send_sms(from_number, "You have not replied YES to the confirmation message. Please reply YES to continue.") and return if u.is_opted_in === false
        jobs_count = u.jobs_count
        send_sms(from_number, "Exceeded free tier limit of 3 active reminders. Reply UPGRADE to upgrade yout account") and return if jobs_count >= 3 && u.tier === "free"
        ai_parsed = ai_sms_parser(body)
        puts ai_parsed
        time = ai_parsed.split("#")[0]
        subject = ai_parsed.split("#")[1]
        type = ai_parsed.split("#")[2]
        formatted_time = Chronic.parse(time)
        if formatted_time.nil? || formatted_time === ""
            send_sms(from_number, "You did not provide a valid date/time. Please try again.")
            return
        end
        job = u.schedule_reminder(formatted_time, subject, type, "sms")
    end

    def phone_call_callback
        phone_number = to_e164(params[:From])
        user = User.find_or_create_by(phone_number: phone_number)
        user.update(account_source: "voice")
        response = Twilio::TwiML::VoiceResponse.new
        response.pause(length: 1)
        response.gather(action: "https://3d1b-2600-4808-53f4-f00-8459-922d-92a3-c1e5.ngrok-free.app/upgrade_or_reminder", num_digits: 1) do |g|
            g.say(voice: "woman", message: "Press 1 if you would like to upgrade your account. Otherwise press 2.")
        end
        response.say(voice: "woman", message: "Did not reach")
        render xml: response.to_s
    end

    def upgrade_or_reminder
        digit = params[:Digits]
        case digit
        when "1"
            response = Twilio::TwiML::VoiceResponse.new
            response.redirect('https://3d1b-2600-4808-53f4-f00-8459-922d-92a3-c1e5.ngrok-free.app/upgrade')
            render xml: response.to_s
        else
            response = Twilio::TwiML::VoiceResponse.new
            response.gather(action: "https://3d1b-2600-4808-53f4-f00-8459-922d-92a3-c1e5.ngrok-free.app/remind", input: "speech", speech_timeout: "1") do |g|
                g.say(voice: "woman", message: "Go ahead")
            end
            response.say(voice: "woman", message: "Did not reach")
            render xml: response.to_s
        end
    end

    def upgrade
        response = Twilio::TwiML::VoiceResponse.new
        response.say(voice: "woman", message: "Upgrading via phone line is not currently available. Neither is is available anywhere else.")
        response.pause(length: 0.75)
        render xml: response.to_s
    end

    def remind
        result = params[:SpeechResult]
        u = User.find_by(phone_number: to_e164(params[:From]))
        ai_parsed = ai_sms_parser_voice(result)
        time = ai_parsed.split("#")[0]
        subject = ai_parsed.split("#")[1]
        type = ai_parsed.split("#")[2]
        formatted_time = Chronic.parse(time)
        job = u.schedule_reminder(formatted_time, subject, type, "voice")
        if job
            response = Twilio::TwiML::VoiceResponse.new
            response.say(voice: "woman", message: "You said #{subject}, at #{time}")
            response.pause(length: 0.75)
            render xml: response.to_s
        else
            response = Twilio::TwiML::VoiceResponse.new
            response.gather(action: "https://3d1b-2600-4808-53f4-f00-8459-922d-92a3-c1e5.ngrok-free.app/remind", input: "speech", speech_timeout: "1") do |g|
                g.say(voice: "woman", message: "Something went wrong, please try again")
            end
            response.say(voice: "woman", message: "Did not reach")
            render xml: response.to_s
        end
    end

    def phone_call_fallback
        puts params
    end
end
