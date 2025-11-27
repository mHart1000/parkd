class AddEnqueuedAtToAlerts < ActiveRecord::Migration[7.2]
  def change
    add_column :alerts, :enqueued_at, :datetime
  end
end
