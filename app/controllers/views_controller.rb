class ViewsController < ApplicationController
    require 'chronic'

    def index
    end
    
    def home
        render json: { message: "App is running", time: Chronic.parse('now') }
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

    def to_e164(pn)
        phone_number = pn
        phone_number.gsub!(/[^0-9]/, "")
        phone_number = "+1#{phone_number[0..2]}-#{phone_number[3..5]}-#{phone_number[6..9]}" if phone_number.length === 10
        phone_number = "+1#{phone_number[1..3]}-#{phone_number[4..6]}-#{phone_number[7..10]}" if phone_number.length === 11
        phone_number
    end
end
