# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# Set the environment
set :environment, ENV["RAILS_ENV"] || "development"
set :output, { error: "log/cron_error.log", standard: "log/cron.log" }

# Build prefecture-based suggestion snapshots at 7:30 AM every day
every 1.day, at: "7:30 am" do
  runner "MorningSuggestionJob.perform_now"
end

# 朝のプッシュ通知（8:00）
every 1.day, at: "8:00 am" do
  runner "MorningNotificationJob.perform_now"
end

# Send daily reminder notification at 8:00 PM (20:00) every day
every 1.day, at: "8:00 pm" do
  runner "DailyReminderJob.perform_now"
end
