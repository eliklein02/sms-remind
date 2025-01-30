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

  post "/send_otp" => "views#send_otp"

  post "/verify_otp" => "views#verify_otp"

  get "/privacy_policy" => "views#privacy_policy"

  get "/terms_and_conditions" => "views#terms_and_conditions"

  post "/delete_reminder" => "views#delete_job"

  post "/phone_call_callback" => "api#phone_call_callback"

  post "/phone_call_fallback" => "api#phone_call_fallback"

  post "/upgrade_or_reminder" => "api#upgrade_or_reminder"

  post "/upgrade" => "api#upgrade"

  post "/remind" => "api#remind"

  # Defines the root path route ("/")
  # root "posts#index"
end
