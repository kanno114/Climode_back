namespace :api do
  namespace :test_data do
    desc "Create test daily logs for API testing"
    task create_daily_logs: :environment do
      require_relative "../../app/services/score_calculator_v1"
      puts "Creating test daily logs..."

      user = User.first
      prefecture = Prefecture.first

      if user.nil?
        puts "No user found. Please run db:seed first."
        return
      end

      if prefecture.nil?
        puts "No prefecture found. Please run db:seed first."
        return
      end

      # 過去30日分のテストデータを作成
      30.times do |i|
        date = i.days.ago.to_date

        # 既存のレコードがある場合はスキップ
        next if DailyLog.exists?(user: user, date: date)

        daily_log = DailyLog.create!(
          user: user,
          prefecture: prefecture,
          date: date,
          sleep_hours: rand(5.0..9.0).round(1),
          mood: rand(-3..3),
          fatigue: rand(-3..3),
          self_score: rand(1..3),
          note: "テストデータ #{i + 1}日目"
        )

        # 体調スコアを計算して更新
        score_result = Score::ScoreCalculatorV1.new(daily_log).call(persist: false)
        daily_log.update(score: score_result[:score])

        puts "Created daily log for #{date}"
      end

      puts "Test daily logs created successfully!"
    end

    desc "Clear all test daily logs"
    task clear_daily_logs: :environment do
      puts "Clearing all daily logs..."
      DailyLog.destroy_all
      puts "All daily logs cleared!"
    end
  end
end
