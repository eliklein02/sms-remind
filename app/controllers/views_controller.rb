class ViewsController < ApplicationController
    require 'chronic'

    include HelperTools

    before_action :authorize_user, only: [ :user ]

    def index
    end

    def home
        render json: { message: "App is running", time: Chronic.parse('now') }
    end

    def dashboard
        users = User.all
        events = Event.all
        events_by_day = Event.group("DATE(created_at)").count
        users_by_day = User.group("DATE(created_at)").count
        respond_to do |f|
            f.html { render :dashboard, locals: { users: users, events: events, users_by_day: users_by_day, events_by_day: events_by_day } }
        end
    end

    def delete_job
        job_id = params[:jobId]
        job = Delayed::Job.find(job_id)
        if job.destroy
            render json: { message: "Successfully deleted the reminder." }
        else
            render json: { message: "Failed to delete the reminder. Please try again in a few minutes." }
        end
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
        @user = User.find(params[:id])
        @reminders = Delayed::Job.where(user_id: @user.id)
        respond_to do |format|
            format.html
            format.json { render json: { user: @user } }
        end
    end

    def send_otp
        pn = params[:phone_number]
        u = User.find_by(phone_number: to_e164(pn))
        render json: { message: "Failure" } and return if u.nil?
        otp = rand(100000..999999).to_s
        u.update(tmp_otp: otp)
        send_sms(params[:phone_number], "Your OTP is #{otp}, do not share this with anybody.")
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

    private

    def authorize_user
        @user = User.find(params[:id])
        unless session[:user_id] == @user.id
            redirect_to root_path
        end
    end
end
