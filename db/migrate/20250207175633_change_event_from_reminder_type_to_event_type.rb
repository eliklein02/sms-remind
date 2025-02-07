class ChangeEventFromReminderTypeToEventType < ActiveRecord::Migration[7.2]
  def change
    rename_column :events, :reminder_type, :event_type
  end
end
