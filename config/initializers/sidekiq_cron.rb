Sidekiq::Cron.configure do |config|
  config.cron_schedule_file = Rails.root.join("config", "schedule.yml").to_s
  config.cron_poll_interval = 10
end
