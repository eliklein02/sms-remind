class ReminderCallJob < ApplicationJob
  include HelperTools

  queue_as :default


  def perform(*args)
    u = args[0]
    about = args[1]
    make_phone_call(u, about)
  end
end
