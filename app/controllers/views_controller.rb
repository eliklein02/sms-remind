class ViewsController < ApplicationController
    require 'chronic'
    
    def index
    end
    
    def home
        render json: { message: "App is running", time: Chronic.parse('now') }
    end
end
