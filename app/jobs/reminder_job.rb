class ReminderJob < ApplicationJob

  require 'twilio-ruby'

  queue_as :default

  def perform(*args)
    puts args[0]
    puts args[1]
  end
end
