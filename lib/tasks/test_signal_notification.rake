namespace :test do
  namespace :signal_notification do
    desc "テスト用のシグナル通知データを作成"
    task setup: :environment do
      puts "=== シグナル通知テスト用データの作成 ==="

      # ユーザーを取得または作成
      user = User.first
      if user.nil?
        puts "エラー: ユーザーが存在しません。先に db:seed を実行してください。"
        exit 1
      end

      puts "ユーザー: #{user.email} (ID: #{user.id})"

      # トリガーを作成または取得
      trigger1 = Trigger.find_or_create_by(key: "pressure_drop") do |t|
        t.label = "気圧低下"
        t.category = "env"
        t.is_active = true
        t.version = 1
        t.rule = {}
      end

      trigger2 = Trigger.find_or_create_by(key: "humidity_high") do |t|
        t.label = "高湿度"
        t.category = "env"
        t.is_active = true
        t.version = 1
        t.rule = {}
      end

      trigger3 = Trigger.find_or_create_by(key: "temperature_drop") do |t|
        t.label = "気温低下"
        t.category = "env"
        t.is_active = true
        t.version = 1
        t.rule = {}
      end

      puts "トリガーを作成/取得しました:"
      puts "  - #{trigger1.key}: #{trigger1.label}"
      puts "  - #{trigger2.key}: #{trigger2.label}"
      puts "  - #{trigger3.key}: #{trigger3.label}"

      # 今日のシグナルイベントを作成（既存のものは削除）
      SignalEvent.where(user: user, evaluated_at: Date.current.beginning_of_day..Date.current.end_of_day).destroy_all

      signal1 = SignalEvent.create!(
        user: user,
        trigger_key: trigger1.key,
        category: "env",
        level: "warning",
        priority: 80,
        evaluated_at: Time.current
      )

      signal2 = SignalEvent.create!(
        user: user,
        trigger_key: trigger2.key,
        category: "env",
        level: "attention",
        priority: 60,
        evaluated_at: Time.current
      )

      signal3 = SignalEvent.create!(
        user: user,
        trigger_key: trigger3.key,
        category: "env",
        level: "strong",
        priority: 90,
        evaluated_at: Time.current
      )

      puts "シグナルイベントを作成しました:"
      puts "  - #{signal1.trigger_key_label} (#{signal1.level_jp}) - 優先度: #{signal1.priority}"
      puts "  - #{signal2.trigger_key_label} (#{signal2.level_jp}) - 優先度: #{signal2.priority}"
      puts "  - #{signal3.trigger_key_label} (#{signal3.level_jp}) - 優先度: #{signal3.priority}"

      # プッシュ通知の登録状況を確認
      subscription_count = user.push_subscriptions.count
      if subscription_count == 0
        puts "\n⚠️  警告: プッシュ通知が登録されていません。"
        puts "   フロントエンドでプッシュ通知を有効化してください。"
        puts "   手順:"
        puts "   1. ブラウザで http://localhost:3000 にアクセス"
        puts "   2. ログイン後、設定画面からプッシュ通知を有効化"
        puts "   3. ブラウザの通知許可を許可"
      else
        puts "\n✅ プッシュ通知登録数: #{subscription_count}"
      end

      puts "\n=== データ作成完了 ==="
      puts "\n次のコマンドでジョブを実行できます:"
      puts "  docker-compose exec back bin/rails test:signal_notification:run"
    end

    desc "シグナル通知ジョブを手動実行"
    task run: :environment do
      puts "=== シグナル通知ジョブを実行 ==="
      puts "実行時刻: #{Time.current}"
      puts ""
      
      # 実行前の状態を確認
      user_count = User.count
      signal_count = SignalEvent.today.count
      subscription_count = PushSubscription.count
      
      puts "実行前の状態:"
      puts "  - ユーザー数: #{user_count}"
      puts "  - 今日のシグナル数: #{signal_count}"
      puts "  - プッシュ通知登録数: #{subscription_count}"
      puts ""
      
      # ジョブを実行
      MorningSignalNotificationJob.perform_now
      
      puts ""
      puts "=== 実行完了 ==="
      puts "ログを確認してください: docker-compose exec back tail -f log/development.log"
    end

    desc "テスト用データのクリーンアップ"
    task cleanup: :environment do
      puts "=== テスト用データのクリーンアップ ==="
      user = User.first
      if user
        deleted = SignalEvent.where(user: user, evaluated_at: Date.current.beginning_of_day..Date.current.end_of_day).destroy_all
        puts "今日のシグナルイベントを #{deleted.count} 件削除しました。"
      end
      puts "=== クリーンアップ完了 ==="
    end

    desc "通知送信の動作確認（モック版）"
    task test_mock: :environment do
      puts "=== 通知送信の動作確認（モック版） ==="
      
      user = User.first
      if user.nil?
        puts "エラー: ユーザーが存在しません。"
        exit 1
      end

      signals = SignalEvent.for_user(user).today.ordered_by_priority
      if signals.empty?
        puts "エラー: 今日のシグナルが存在しません。先に setup を実行してください。"
        exit 1
      end

      top = signals.limit(3)
      title = "今日のシグナル：#{top.first.trigger_key_label}"
      body = top.map { |s| "#{s.trigger_key_label}（#{s.level_jp}）" }.join("・")

      puts "通知内容:"
      puts "  タイトル: #{title}"
      puts "  本文: #{body}"
      puts "  URL: /dashboard"
      puts ""
      puts "プッシュ通知登録数: #{user.push_subscriptions.count}"
      
      if user.push_subscriptions.any?
        puts "✅ この内容で通知が送信されます。"
      else
        puts "⚠️  プッシュ通知が登録されていないため、実際には送信されません。"
      end
    end
  end
end
