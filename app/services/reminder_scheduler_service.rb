class ReminderSchedulerService
    include HelperTools

    def initialize(user, type, subject, time, reminder_source)
        @user = user
        @type = type
        @subject = subject
        @time = time
        @reminder_source = reminder_source
    end

    def schedule_reminder
        puts "Im in the service!!"
        puts @user
        puts @type
        puts @subject
        puts @time
        puts @reminder_source

        # @user.account_source == "voice" ? ai_parsed = ai_parser(@body, "voice") : ai_parsed = ai_parser(@body, "sms")
        # time = ai_parsed.split("#")[0]
        # subject = ai_parsed.split("#")[1]
        # type = ai_parsed.split("#")[2]

        time = Time.strptime(@time, "%Y-%m-%d, %I:%M:%S %p %Z")
        time_parsed = time.in_time_zone(@user.time_zone || 'Eastern Time (US & Canada)').strftime("%A, %B %d, %Y, at %I:%M %p")


        if time_parsed.nil? || time_parsed === ""
            send_sms(@user.phone_number, "You did not provide a valid date/time. Please try again.")
            return
        end

        case @type
        when "sms"
            job = schedule_sms_reminder(time, time_parsed, @subject)
        when "voice"
            job = schedule_voice_reminder(time, time_parsed, @subject)
        end
        job
    end

    def ai_parser(input, account_source)
        account_source == "voice" ? default = "voice" : default = "sms"
        default == "voice" ? reverse = "sms" : reverse = "voice"
        now = Time.current
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
                                        As for the third section, the type, by default you will return as #{default}, unless the user specifies that the reminder type should be #{reverse}, which in that case you will return
                                        #{reverse}, (NOT IF THE SUBJECT INCLUDES A PHONE CALL AS WHAT THEY NEED TO BE REMINDED ABOUT, YOU WILL UNDERSTAND THE DIFFERENCE.
                                        Here is the current time: #{now}
                                        Here is the user's time: #{input}" }
            ],
            temperature: 0.7
          }
        )
        response.dig("choices", 0, "message", "content")
    end

    def schedule_sms_reminder(time, time_parsed, subject)
        sms_jobs_count = @user.sms_jobs_count
        send_sms(@user.phone_number, "Exceeded free tier limit of 2 active sms reminders. Reply UPGRADE to upgrade yout account") and return if sms_jobs_count >= 2 && @user.tier === "free" && @type == "sms"

        job = ReminderJob.set(wait_until: time).perform_later(@user.id, subject)
        x = Delayed::Job.find_by(id: job.provider_job_id)&.update!(user_id: @user.id)
        x = Delayed::Job.find_by(id: job.provider_job_id)
        event = Event.create(user_phone_number: @user.phone_number, event_type: "SMS Reminder", run_at: @time)
        send_sms(@user.phone_number, "Your reminder (#{subject}) has been set for #{time_parsed}. Reply 'Cancel #{x.id}' to cancel.")
        [ x, event ]
    end

    def schedule_voice_reminder(time, time_parsed, subject)
        voice_jobs_count = @user.voice_jobs_count
        send_sms(@user.phone_number, "Exceeded free tier limit of 1 active voice reminder. Reply UPGRADE to upgrade yout account") and return if voice_jobs_count >= 1 && @user.tier === "free" && @type == "voice"

        job = ReminderCallJob.set(wait_until: time).perform_later(@user.id, subject)
        x = Delayed::Job.find_by(id: job.provider_job_id)&.update!(user_id: @user.id)
        x = Delayed::Job.find_by(id: job.provider_job_id)
        if @reminder_source == "sms"
            send_sms(@user.phone_number, "Your call reminder (#{subject}) has been set for #{time_parsed}.  Reply 'Cancel #{x.id}' to cancel.")
        end
        event = Event.create(user_phone_number: @user.phone_number, event_type: "Voice Reminder", run_at: @time)
        [ x, event ]
    end
end
