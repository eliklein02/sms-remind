class ApiController < ApplicationController
    require 'chronic'
    require 'nokogiri'
    require 'twilio-ruby'
    require 'net/http'


    include HelperTools



    skip_before_action :verify_authenticity_token


    def twilio_webhook
        from_number = params[:From]
        body = params[:Body]
        body_down = body.downcase
        body_first_word = body_down.split(" ")[0]
        case body_first_word
        when "register", "signup"
            user = User.find_or_initialize_by(phone_number: from_number)
            send_sms(from_number, "You are already registered with Remind.") and return if user.persisted?
            user.account_source ||= "sms"
            user.save if user.new_record?
        when "upgrade"
            send_sms(from_number, "To upgrade your account, please call this number and dial 1.") and return
        when "finance"
            ai_parsed = ai_elimelech(body)
            send_sms(from_number, ai_parsed)
        when "cancel"
            job_id = body_down.split(" ")[1]
            job = Delayed::Job.find(job_id)
            return if job.nil?
            sender = User.find_by(phone_number: to_e164(from_number))
            job_user = User.find(job.user_id)
            send_sms(from_number, "Nice try") and return if job_user.id != sender.id
            job.destroy
            send_sms(from_number, "Reminder has been successfully cancelled.")
        when "help"
            send_sms(from_number, "Welcome to Remind. You can set reminders by replying with the time and subject of the reminder. For example, 'remind me in 5 minutes to call mom', or 'remind me on december 5 about David's wedding'.")
            send_sms(from_number, "To register, reply with 'register'. To upgrade your account, reply with 'upgrade'. To cancel a reminder, reply with 'cancel [reminder id]', to opt out, reply 'STOP'.")
            send_sms(from_number, "You can also set reminders by calling this number and dialing 2.")
            send_sms(from_number, "You will be reminded via sms by default, to be reminded via phone call, specify so in the reminder.") and return
        when "word"
            word = body.split(" ")[1]
            definition = get_definition(word)
            send_sms(from_number, definition)
            Event.create(user_phone_number: from_number, event_type: "Dictionary Query")
        else
            handle_reminder(from_number, body)
        end
        render json: { message: "All Good" }, status: :ok
    end

    def ai_parser(input, account_source, user_id)
        account_source == "voice" ? default = "voice" : default = "sms"
        default == "voice" ? reverse = "sms" : reverse = "voice"
        now = Time.now.utc
        now = now.strftime("%Y-%m-%d (%A) %I:%M:%S %p, %Z")
        User.find(user_id).time_zone.present? ? time_zone = User.find(user_id).time_zone : time_zone = "Eastern Time (US & Canada)"
        client = OpenAI::Client.new
        response = client.chat(
          parameters: {
            model: "gpt-4o",
            messages: [
                { role: "user", content: 
                                        # "You are a natural language time parser. You will return the time and subject and type of reminder given to you by a human in the following format in UTC: 'yyyy-mm-dd, hh:mm:ss (AM/PM), UTC#subject of the reminder#type of reminder#logic you used to get the timing and time zones and hours correct, including details like hours and time zone differneces and why you returned the given hour.
                                        # You will take the current time, and I will provide the time zone that the message is coming from, and use the natural language time given to you by the user to return the time in the format I just mentioned, taking into consideration the time zone differences.
                                        # If no time is provided, and there is only a subject, you will return the time as one hour from now.
                                        # You will use some logical reasoning to determine the time (ie, if the current time is after midnight, but before 4am, and the user says something
                                        # including 'tomorrow', or the like, you will return the date as the same day because that is what they mean.
                                        # Or another example, if the user says a specific time, you will return the next instance of that time on the clock, so if now is 1pm and they say 1 oclock that means 1am and so forth, unless of course specified otherwise.)
                                        # You will return ONLY the time in the format I mentioned, and no more words.
                                        # Seconds are also valid, they might say in a minute and 30 seconds, and you will return the current time plus 1 minute and 30 seconds and so forth for other time increments.
                                        # You will also return the subject with correct capitalization and corrected spelling errors after the # like we discussed.
                                        # As for the third section, the type, by default you will return as #{default}, unless the user specifies that the reminder type should be #{reverse}, which in that case you will return
                                        # #{reverse}, (NOT IF THE SUBJECT INCLUDES A PHONE CALL AS WHAT THEY NEED TO BE REMINDED ABOUT, YOU WILL UNDERSTAND THE DIFFERENCE).
                                        # Here is the user's time zone: #{time_zone}
                                        # Here is the current time: #{now}
                                        # Here is the user's input: #{input}" 
                                         "You are a natural language time parser. Return the time, subject, and type of reminder given by a human in the following format in UTC:
                                         yyyy-mm-dd, hh:mm:ss AM/PM UTC#subject of the reminder#type of reminder
                                         here is the user's input: #{input}
                                            Rules:
                                                1.	Use UTC as the Primary Time Reference:

                                                •	The current UTC time is: #{now}.
                                                •	The user’s time zone is: #{time_zone}.
                                                •	Always start from the UTC time provided and apply time zone offsets to determine the local time.
                                                •	Ensure that AM/PM transitions are correctly handled when converting back to UTC.

                                                2.	Basic Logic for Parsing Time:
                                                •   If the user uses the term morning, that means 9 am
                                                •	If no time is provided, return the time as one hour from now.
                                                •	If the user provides a time without AM/PM, assume the next logical occurrence (e.g., if it’s 1 PM and they say “4 o’clock,” assume 4 PM).
                                                •	If multiple times are mentioned, use the earliest one unless the user specifies otherwise.

                                                3.	Handling Time Phrases:

                                                •	‘Midnight’ = 00:00, ‘Noon’ = 12:00 PM.
                                                •	‘Now’ = Round up to the next full minute in UTC time.
                                                •	‘A few hours’ = 3 hours, ‘Later today’ = 6-8 hours.
                                                •	‘End of the day’ = 11:59 PM, ‘Beginning of the day’ = 6 AM.

                                                4.	Weekdays and Recurring Reminders:

                                                •	‘Next [day of the week]’ = The next instance of that day unless today is that day and the time has not yet passed.
                                                •	If a recurring reminder is requested (e.g., ‘every day at 8 AM’), indicate recurrence in the response.

                                                5.	Time Zone Handling and DST Consideration:

                                                •	Always apply the correct UTC offset for the given time zone and current date.
                                                •	Consider Daylight Saving Time (DST) adjustments when necessary.
                                                •	Never manually convert local time back to UTC—calculate everything directly from UTC first.

                                                6.	Reminder Type:

                                                •	Default type: #{default}.
                                                •	If the user specifies the other type (#{reverse}), use it unless the subject involves a phone call.

                                            Final Requirement:

                                            Return ONLY the formatted time, subject, and type. Correct any spelling errors in the subject, but do not add extra words."
                                    }
            ],
            temperature: 0.7
          }
        )
        response.dig("choices", 0, "message", "content")
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

    def get_definition(word)
        url = "https://www.dictionaryapi.com/api/v3/references/collegiate/json/#{word}?key=#{ENV['DICTIONARY_API_KEY']}"
        uri = URI(url)
        response = Net::HTTP.get(uri)
        response = JSON.parse(response)
        full_definition = response[0]["shortdef"]
        to_send = []
        full_definition.each_with_index do |e, i|
            to_send << "#{i+1}: #{e}"
        end
        to_send = to_send.join(". ")
        return to_send
    end

    def do_something
        time = Chronic.parse('in 5 seconds')
        respond_to do |format|
            format.json { render json: { message: "Scheduled reminder for #{time}" } }
        end
    end

    def handle_reminder(from_number, body)
        u = validate_user(from_number)
        return if u.nil?
        u.account_source == "voice" ? ai_parsed = ai_parser(body, "voice", u.id) : ai_parsed = ai_parser(body, "sms", u.id)
        puts ai_parsed
        time = ai_parsed.split("#")[0]
        subject = ai_parsed.split("#")[1]
        type = ai_parsed.split("#")[2]
        job_scheduler = ReminderSchedulerService.new(u, type, subject, time, "sms").schedule_reminder
    end

    def validate_user(phone_number)
        u = User.find_by(phone_number: to_e164(phone_number))
        send_sms(from_number, "You are not registered to receive messages from Remind. Please reply with 'register' to sign up.") and return if u.nil?
        u
    end

    def phone_call_callback
        phone_number = to_e164(params[:From])
        user = User.find_or_initialize_by(phone_number: phone_number)
        user.account_source ||= "voice"
        is_new_user = user.new_record?
        user.save if user.new_record?
        if is_new_user
            response = Twilio::TwiML::VoiceResponse.new
            response.pause(length: 1)
            response.gather(action: "#{ENV['BASE_URL']}/upgrade_or_reminder", num_digits: 1) do |g|
                g.say(voice: "woman", message: "Welcome to remind. Press 1 if you would like to upgrade your account. Please keep in mind that setting reminders via a phone call will default to calling you, specify if you would like to be reminded via sms. Press 2 to set a reminder. Press 3 for instructions.")
            end
            response.say(voice: "woman", message: "Did not reach")
            render xml: response.to_s
        else
            response = Twilio::TwiML::VoiceResponse.new
            response.pause(length: 1)
            response.gather(action: "#{ENV['BASE_URL']}/upgrade_or_reminder", num_digits: 1) do |g|
                g.say(voice: "woman", message: "Press 1 if you would like to upgrade your account. Press 2 to set a reminder. Press 3 for instructions.")
            end
            response.say(voice: "woman", message: "Did not reach")
            render xml: response.to_s
        end
    end

    def upgrade_or_reminder
        digit = params[:Digits]
        case digit
        when "1"
            response = Twilio::TwiML::VoiceResponse.new
            response.redirect("#{ENV['BASE_URL']}/upgrade")
            render xml: response.to_s
        when "2"
            response = Twilio::TwiML::VoiceResponse.new
            response.gather(action: "#{ENV['BASE_URL']}/remind", input: "speech", speech_timeout: "2") do |g|
                g.say(voice: "woman", message: "Go ahead")
            end
            response.say(voice: "woman", message: "Did not reach")
            render xml: response.to_s
        when "3"
            response = Twilio::TwiML::VoiceResponse.new
            response.say(voice: "woman", message: "Welcome to Remind. You can set reminders by speaking the time and subject of the reminder. For example, 'remind me in 5 minutes to call mom', or 'remind me on december 5 about David's wedding'.")
            response.pause(length: 0.50)
            response.say(voice: "woman", message: "You will be reminded via voice by default, to be reminded via sms, specify so in the reminder.")
            response.pause(length: 0.75)
            render xml: response.to_s
        else
            response = Twilio::TwiML::VoiceResponse.new
            response.say(voice: "woman", message: "That is not a valid option.")
            render xml: response.to_s
        end
    end

    def upgrade
        response = Twilio::TwiML::VoiceResponse.new
        response.gather(action: "#{ENV['BASE_URL']}/collect_cc_info_endpoint", input: "dtmf", num_digits: 16) do |g|
            g.say(voice: "woman", message: "Please enter your credit card number")
        end
        render xml: response.to_s
    end

    def collect_cc_info_endpoint
        response = Twilio::TwiML::VoiceResponse.new
        response.say(voice: "woman", message: params[:Digits])
        render xml: response.to_s
    end

    def remind
        body = params[:SpeechResult]
        u = User.find_by(phone_number: to_e164(params[:From]))
        u.account_source == "voice" ? ai_parsed = ai_parser(body, "voice", u.id) : ai_parsed = ai_parser(body, "sms", u.id)
        time = ai_parsed.split("#")[0]
        subject = ai_parsed.split("#")[1]
        type = ai_parsed.split("#")[2]
        formatted_time = Chronic.parse(time)

        sms_jobs_count = u.sms_jobs_count
        voice_jobs_count = u.voice_jobs_count

        if sms_jobs_count >= 2 && u.tier == "free" && type == "sms"
            response = Twilio::TwiML::VoiceResponse.new
            response.say(voice: "woman", message: "Exceeded free tier limit of 2 active sms reminders. Reply UPGRADE to upgrade yout account")
            response.pause(length: 0.75)
            render xml: response.to_s and return
        end
        if voice_jobs_count >= 1 && u.tier == "free" && type == "voice"
            response = Twilio::TwiML::VoiceResponse.new
            response.say(voice: "woman", message: "Exceeded free tier limit of 1 active voice reminder. Reply UPGRADE to upgrade yout account")
            response.pause(length: 0.75)
            render xml: response.to_s and return
        end
        job_scheduler = ReminderSchedulerService.new(u, type, subject, time, "voice").schedule_reminder
        if job_scheduler
            response = Twilio::TwiML::VoiceResponse.new
            response.say(voice: "woman", message: "You will be reminded to #{subject}, at #{time}")
            response.pause(length: 0.75)
            render xml: response.to_s
        else
            response = Twilio::TwiML::VoiceResponse.new
            response.gather(action: "#{ENV['BASE_URL']}/remind", input: "speech", speech_timeout: "1") do |g|
                g.say(voice: "woman", message: "Something went wrong, please try again")
            end
            response.say(voice: "woman", message: "Did not reach")
            render xml: response.to_s
        end
    end

    def phone_call_fallback
        puts params
    end

    def chat_gpt
        input = params[:body]
        client = OpenAI::Client.new
        response = client.chat(
          parameters: {
            model: "gpt-4o",
            messages: [
                { role: "user", content: "You will answer the following question in 30 words or less: #{input}" }
            ],
            temperature: 0.7
          }
        )
        render json: { message: response.dig("choices", 0, "message", "content") }
    end
end
