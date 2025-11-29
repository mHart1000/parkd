class AddNotificationLeadTimeHoursToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :notification_lead_time_hours, :integer
  end
end
