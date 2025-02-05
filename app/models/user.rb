class User < ApplicationRecord
    require 'chronic'
    require 'sendgrid-ruby'
    include SendGrid

    after_create :to_e164, :sign_em_up

    enum tier: { free: 0, paid: 1 }

    def sign_em_up
        return if self.account_source == "voice"
        account_sid = ENV['TWILIO_ACCOUNT_SID']
        auth_token = ENV['TWILIO_AUTH_TOKEN']
        twilio_phone_number = ENV['TWILIO_PHONE_NUMBER']
        @client = Twilio::REST::Client.new(account_sid, auth_token)
        message = @client.messages.create(
            from: twilio_phone_number,
            body: "Thank you for signing up to Remind. Message and data rates may apply. View our privacy policy at http://192dnsserver.com/privacy_policy, and out terms and conditions at http://192dnsserver.com/terms_and_conditions. Reply STOP to opt out. ",
            to: self.phone_number
            )
        self.update_column(:is_opted_in, :true)
        self.update_column(:account_source, "sms")
        notify_me(self.phone_number)
    end

    def to_e164
        phone_number = self.phone_number
        phone_number.gsub!(/[^0-9]/, '')
        phone_number = "+1#{phone_number[0..2]}-#{phone_number[3..5]}-#{phone_number[6..9]}" if phone_number.length === 10
        phone_number = "+1#{phone_number[1..3]}-#{phone_number[4..6]}-#{phone_number[7..10]}" if phone_number.length === 11
        self.update_column(:phone_number, phone_number)
    end

    def list_jobs
        jobs = []
        j = Delayed::Job.where(user_id: self.id)
        j.each do |jo|
            jobs << jo
        end
        jobs
    end

    def list_sms_jobs
        jobs = []
        j = Delayed::Job.where(user_id: self.id)
        j.each do |job|
            job_data = YAML.safe_load(job.handler, permitted_classes: [ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper])
            if job_data.job_data["job_class"] == "ReminderJob"
                jobs << job
            end
        end
        jobs
    end

    def list_voice_jobs
        jobs = []
        j = Delayed::Job.where(user_id: self.id)
        j.each do |job|
            job_data = YAML.safe_load(job.handler, permitted_classes: [ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper])
            if job_data.job_data["job_class"] == "ReminderCallJob"
                jobs << job
            end
        end
        jobs
    end

    def sms_jobs_count
        list_sms_jobs.count
    end

    def voice_jobs_count
        list_voice_jobs.count
    end

    def notify_me(who)
        from = Email.new(email: 'info@192dnsserver.com')
        to = Email.new(email: 'eliklein02@gmail.com')
        subject = "New User Signup"
        content = Content.new(type: 'text/plain', value: "A new user has signed up with the phone number: #{who}")
        mail = Mail.new(from, subject, to, content)


        sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
        response = sg.client.mail._('send').post(request_body: mail.to_json)
    end

    def self.list_numbers
        users = []
        User.all.each do |u|
            users << u.phone_number
        end
        users
    end

    def schedule_reminder(time, subject, type, reminder_source)
        time = Time.parse(time.to_s)
        time_est = time.in_time_zone('Eastern Time (US & Canada)')
        time_parsed = time.strftime("%A, %B %d, %Y, at %I:%M:%S %p")
        time_utc = time_est.utc
        case type
        when "sms"
            job = ReminderJob.set(wait_until: time_utc).perform_later(self.id, subject)
            x = Delayed::Job.find_by(id: job.provider_job_id)&.update!(user_id: self.id)
            x = Delayed::Job.find_by(id: job.provider_job_id)
            event = Event.create(user_phone_number: self.phone_number, reminder_type: "SMS Reminder", run_at: time)
            send_sms(self.phone_number, "Your reminder (#{subject}) has been set for #{time_parsed}. Reply 'Cancel #{x.id}' to cancel.")
            x
        when "voice"
            job = ReminderCallJob.set(wait_until: time_utc).perform_later(self.id, subject)
            x = Delayed::Job.find_by(id: job.provider_job_id)&.update!(user_id: self.id)
            x = Delayed::Job.find_by(id: job.provider_job_id)
            if reminder_source == "sms"
                send_sms(self.phone_number, "Your call reminder (#{subject}) has been set for #{time_parsed}.  Reply 'Cancel #{x.id}' to cancel.")
            end
            event = Event.create(user_phone_number: self.phone_number, reminder_type: "Voice Reminder", run_at: time)
            x
        end
    end

    def send_sms(to, what)
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
        puts message
    end
end
