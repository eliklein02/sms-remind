class ViewsController < ApplicationController
    require 'chronic'

    before_action :authorize_user, only: [ :user ]

    def index
    end

    def home
        render json: { message: "App is running", time: Chronic.parse('now') }
    end

    def privacy_policy
    end

    def terms_and_conditions
    end

    def check_phone_number
        number = to_e164(params[:phone_number])
        puts number
        @user = User.find_or_create_by(phone_number: number)
        redirect_to user_path(@user)
    end

    def user
        @u = User.find(params[:id])
        @reminders = Delayed::Job.where(user_id: @u.id)
        respond_to do |format|
            format.html
            format.json { render json: { user: @u } }
        end
    end

    def send_otp
        pn = params[:phone_number]
        u = User.find_by(phone_number: to_e164(pn))
        render json: { message: "Failure" } and return if u.nil?
        otp = rand(100000..999999).to_s
        u.update(tmp_otp: otp)
        # send_sms(params[:phone_number], "Your OTP is #{otp}, do not share this with anybody.")
        render json: { message: "Success" }
    end

    def verify_otp
        phone_number = to_e164(params[:phone_number])
        @user = User.find_by(phone_number: phone_number)
        otp = params[:otp]
        if @user.tmp_otp == otp
            session[:user_id] = @user.id
            render json: { message: "otp_verified", redirect_path: user_path(@user) }
        else
            render json: { message: "failed" }, status: :unprocessable_entity
        end
    end

    def to_e164(pn)
        phone_number = pn
        phone_number.gsub!(/[^0-9]/, "")
        phone_number = "+1#{phone_number[0..2]}-#{phone_number[3..5]}-#{phone_number[6..9]}" if phone_number.length === 10
        phone_number = "+1#{phone_number[1..3]}-#{phone_number[4..6]}-#{phone_number[7..10]}" if phone_number.length === 11
        phone_number
    end

    private

    def authorize_user
        @user = User.find(params[:id])
        unless session[:user_id] == @user.id
            redirect_to root_path
        end
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
end
