class AddSentAtToAlerts < ActiveRecord::Migration[7.2]
  def change
    add_column :alerts, :sent_at, :datetime
  end
end
