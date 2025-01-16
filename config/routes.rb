Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "views#index"

  get "home" => "views#home"

  post "/check_phone_number" => "views#check_phone_number"

  post "/do_something" => "api#do_something"

  get "/test_json" => "api#test_json" 

  post "/twilio_webhook" => "api#twilio_webhook"

  get "/user/:id" => "views#user", as: "user"

  # Defines the root path route ("/")
  # root "posts#index"
end
