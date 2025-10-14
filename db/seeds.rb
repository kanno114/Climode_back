puts "Resetting database..."
# 既存のデータを削除（外部キー制約を考慮して順序を調整）
DailyLogSymptom.delete_all
WeatherObservation.delete_all
DailyLog.delete_all
UserIdentity.delete_all
User.delete_all
Symptom.delete_all
Prefecture.delete_all

puts "Seeding users..."

users = [
  { name: "Alice", email: "alice@example.com", password: "password123", password_confirmation: "password123" },
  { name: "Bob", email: "bob@example.com", password: "password123", password_confirmation: "password123" },
  { name: "Carol", email: "carol@example.com", password: "password123", password_confirmation: "password123" }
]

users.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.assign_attributes(attrs)
  if user.new_record? || user.changed?
    user.save!
    puts "  upserted: #{user.email}"
  else
    puts "  unchanged: #{user.email}"
  end
end

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# 都道府県データ
prefectures_data = [
  { code: '01', name_ja: '北海道', centroid_lat: 43.064359, centroid_lon: 141.346814 },
  { code: '02', name_ja: '青森県', centroid_lat: 40.824308, centroid_lon: 140.740259 },
  { code: '03', name_ja: '岩手県', centroid_lat: 39.703619, centroid_lon: 141.152684 },
  { code: '04', name_ja: '宮城県', centroid_lat: 38.268837, centroid_lon: 140.872103 },
  { code: '05', name_ja: '秋田県', centroid_lat: 39.718600, centroid_lon: 140.102334 },
  { code: '06', name_ja: '山形県', centroid_lat: 38.240437, centroid_lon: 140.363634 },
  { code: '07', name_ja: '福島県', centroid_lat: 37.750299, centroid_lon: 140.467521 },
  { code: '08', name_ja: '茨城県', centroid_lat: 36.341813, centroid_lon: 140.446793 },
  { code: '09', name_ja: '栃木県', centroid_lat: 36.565725, centroid_lon: 139.883565 },
  { code: '10', name_ja: '群馬県', centroid_lat: 36.390668, centroid_lon: 139.060406 },
  { code: '11', name_ja: '埼玉県', centroid_lat: 35.857428, centroid_lon: 139.648933 },
  { code: '12', name_ja: '千葉県', centroid_lat: 35.605058, centroid_lon: 140.123308 },
  { code: '13', name_ja: '東京都', centroid_lat: 35.689521, centroid_lon: 139.691704 },
  { code: '14', name_ja: '神奈川県', centroid_lat: 35.447753, centroid_lon: 139.642514 },
  { code: '15', name_ja: '新潟県', centroid_lat: 37.902418, centroid_lon: 139.023221 },
  { code: '16', name_ja: '富山県', centroid_lat: 36.695291, centroid_lon: 137.211338 },
  { code: '17', name_ja: '石川県', centroid_lat: 36.594682, centroid_lon: 136.625573 },
  { code: '18', name_ja: '福井県', centroid_lat: 36.065219, centroid_lon: 136.221642 },
  { code: '19', name_ja: '山梨県', centroid_lat: 35.664158, centroid_lon: 138.568449 },
  { code: '20', name_ja: '長野県', centroid_lat: 36.651289, centroid_lon: 138.181224 },
  { code: '21', name_ja: '岐阜県', centroid_lat: 35.391227, centroid_lon: 136.722291 },
  { code: '22', name_ja: '静岡県', centroid_lat: 34.976978, centroid_lon: 138.383054 },
  { code: '23', name_ja: '愛知県', centroid_lat: 35.180188, centroid_lon: 136.906564 },
  { code: '24', name_ja: '三重県', centroid_lat: 34.730283, centroid_lon: 136.508591 },
  { code: '25', name_ja: '滋賀県', centroid_lat: 35.004531, centroid_lon: 135.868590 },
  { code: '26', name_ja: '京都府', centroid_lat: 35.021004, centroid_lon: 135.755608 },
  { code: '27', name_ja: '大阪府', centroid_lat: 34.686316, centroid_lon: 135.519711 },
  { code: '28', name_ja: '兵庫県', centroid_lat: 34.690279, centroid_lon: 135.195511 },
  { code: '29', name_ja: '奈良県', centroid_lat: 34.685333, centroid_lon: 135.832744 },
  { code: '30', name_ja: '和歌山県', centroid_lat: 34.226034, centroid_lon: 135.167506 },
  { code: '31', name_ja: '鳥取県', centroid_lat: 35.503869, centroid_lon: 134.237672 },
  { code: '32', name_ja: '島根県', centroid_lat: 35.472297, centroid_lon: 133.050499 },
  { code: '33', name_ja: '岡山県', centroid_lat: 34.661750, centroid_lon: 133.934675 },
  { code: '34', name_ja: '広島県', centroid_lat: 34.396560, centroid_lon: 132.459622 },
  { code: '35', name_ja: '山口県', centroid_lat: 34.186121, centroid_lon: 131.470500 },
  { code: '36', name_ja: '徳島県', centroid_lat: 34.065770, centroid_lon: 134.559304 },
  { code: '37', name_ja: '香川県', centroid_lat: 34.340149, centroid_lon: 134.043444 },
  { code: '38', name_ja: '愛媛県', centroid_lat: 33.841660, centroid_lon: 132.765362 },
  { code: '39', name_ja: '高知県', centroid_lat: 33.559705, centroid_lon: 133.531080 },
  { code: '40', name_ja: '福岡県', centroid_lat: 33.606785, centroid_lon: 130.418314 },
  { code: '41', name_ja: '佐賀県', centroid_lat: 33.249367, centroid_lon: 130.298822 },
  { code: '42', name_ja: '長崎県', centroid_lat: 32.744839, centroid_lon: 129.873756 },
  { code: '43', name_ja: '熊本県', centroid_lat: 32.789828, centroid_lon: 130.741667 },
  { code: '44', name_ja: '大分県', centroid_lat: 33.238194, centroid_lon: 131.612591 },
  { code: '45', name_ja: '宮崎県', centroid_lat: 31.911090, centroid_lon: 131.423855 },
  { code: '46', name_ja: '鹿児島県', centroid_lat: 31.560148, centroid_lon: 130.557981 },
  { code: '47', name_ja: '沖縄県', centroid_lat: 26.212401, centroid_lon: 127.680932 }
]

prefectures_data.each do |prefecture_data|
  Prefecture.find_or_create_by!(code: prefecture_data[:code]) do |prefecture|
    prefecture.name_ja = prefecture_data[:name_ja]
    prefecture.centroid_lat = prefecture_data[:centroid_lat]
    prefecture.centroid_lon = prefecture_data[:centroid_lon]
  end
end

# 症状マスタデータ（フロントエンドのフォームと一致）
symptoms_data = [
  { code: 'headache', name: '頭痛' },
  { code: 'dizziness', name: 'めまい' },
  { code: 'nausea', name: '吐き気' },
  { code: 'fatigue', name: '倦怠感' },
  { code: 'shoulder_pain', name: '肩こり' },
  { code: 'back_pain', name: '腰痛' },
  { code: 'stomach_ache', name: '腹痛' },
  { code: 'fever', name: '発熱' },
  { code: 'cough', name: '咳' },
  { code: 'runny_nose', name: '鼻水' },
  { code: 'eye_strain', name: '目の疲れ' },
  { code: 'insomnia', name: '不眠' },
  { code: 'loss_of_appetite', name: '食欲不振' },
  { code: 'other', name: 'その他' }
]

symptoms_data.each do |symptom_data|
  Symptom.find_or_create_by!(code: symptom_data[:code]) do |symptom|
    symptom.name = symptom_data[:name]
  end
end

# サンプルの日次記録データ
puts "Creating sample daily logs..."

# Aliceのサンプル記録
alice = User.find_by(email: 'alice@example.com')
if alice
  # 過去30日分のサンプルデータ（今日は除く）
  (1..30).each do |days_ago|
    date = Date.current - days_ago.days

    # 既存の記録があるかチェック
    existing_log = DailyLog.find_by(user: alice, date: date)
    next if existing_log

    # ランダムな体調データを生成
    sleep_hours = rand(5.0..9.0).round(1)
    mood_score = rand(3..9)
    fatigue_score = rand(2..8) # 疲労感スコア（1-10の範囲）

    # ランダムな症状を選択（0-3個）
    symptom_count = rand(0..3)
    selected_symptoms = symptoms_data.sample(symptom_count).map { |s| s[:code] }

    # 天候データ
    weather_conditions = [ '晴れ', '曇り', '雨', '雪', '霧', '雷' ]
    weather_condition = weather_conditions.sample
    temperature = rand(10.0..30.0).round(1)
    humidity = rand(30..80)
    pressure = rand(1000.0..1020.0).round(1)

    # スコア計算（睡眠、気分、疲労感、症状数を考慮）
    base_score = 50 # ベーススコア

    # 睡眠スコア（7-8時間が最適）
    sleep_score = case sleep_hours
    when 7.0..8.0
      20
    when 6.0..6.9, 8.1..9.0
      15
    when 5.0..5.9, 9.1..10.0
      10
    else
      5
    end

    # 気分スコア
    mood_bonus = (mood_score - 5) * 2 # -5から5の範囲を-10から10に変換

    # 疲労感スコア（疲労感が少ないほど高スコア）
    fatigue_bonus = (10 - fatigue_score) * 1.5

    # 症状数による減点
    symptom_penalty = symptom_count * 5

    # 総合スコア計算
    total_score = [ base_score + sleep_score + mood_bonus + fatigue_bonus - symptom_penalty, 100 ].min
    total_score = [ total_score, 0 ].max

    # メモ（気分と疲労感を考慮）
    notes = case [ mood_score, fatigue_score ]
    in [ 8..9, 1..3 ]
      "体調が良く、充実した一日でした。疲れも少なく快調です。"
    in [ 6..7, 1..4 ]
      "普通の一日でした。特に問題なし。"
    in [ 4..5, 5..7 ]
      "少し疲れを感じました。"
    in [ 1..3, 8..10 ]
      "体調が優れませんでした。疲労感が強いです。"
    else
      "普通の一日でした。"
    end

    # デフォルトの都道府県（東京都）を取得
    default_prefecture = Prefecture.find_by(code: '13')

    daily_log = DailyLog.create!(
      user: alice,
      prefecture: default_prefecture,
      date: date,
      sleep_hours: sleep_hours,
      mood: mood_score - 5, # moodは-5から5の範囲なので変換
      fatigue: fatigue_score - 5, # fatigueは-5から5の範囲なので変換
      memo: notes,
      score: total_score
    )

    # 天候データを別テーブルに保存
    WeatherObservation.create!(
      daily_log: daily_log,
      temperature_c: temperature,
      humidity_pct: humidity,
      pressure_hpa: pressure,
      observed_at: date.to_datetime,
      snapshot: {
        weather_condition: weather_condition
      }
    )

    # 症状を関連付け
    selected_symptoms.each do |symptom_code|
      symptom = Symptom.find_by(code: symptom_code)
      if symptom
        DailyLogSymptom.create!(
          daily_log: daily_log,
          symptom: symptom
        )
      end
    end

    puts "  Created daily log for Alice on #{date}: sleep=#{sleep_hours}h, mood=#{mood_score}, fatigue=#{fatigue_score}, score=#{total_score}, symptoms=#{selected_symptoms.join(', ')}"
  end
end

# Bobのサンプル記録
bob = User.find_by(email: 'bob@example.com')
if bob
  # 過去30日分のサンプルデータ（今日は除く）
  (1..30).each do |days_ago|
    date = Date.current - days_ago.days

    # 既存の記録があるかチェック
    existing_log = DailyLog.find_by(user: bob, date: date)
    next if existing_log

    # ランダムな体調データを生成
    sleep_hours = rand(6.0..8.5).round(1)
    mood_score = rand(4..8)
    fatigue_score = rand(3..7) # 疲労感スコア（1-10の範囲）

    # ランダムな症状を選択（0-2個）
    symptom_count = rand(0..2)
    selected_symptoms = symptoms_data.sample(symptom_count).map { |s| s[:code] }

    # 天候データ
    weather_conditions = [ '晴れ', '曇り', '雨' ]
    weather_condition = weather_conditions.sample
    temperature = rand(15.0..25.0).round(1)
    humidity = rand(40..70)
    pressure = rand(1005.0..1015.0).round(1)

    # スコア計算（睡眠、気分、疲労感、症状数を考慮）
    base_score = 50 # ベーススコア

    # 睡眠スコア（7-8時間が最適）
    sleep_score = case sleep_hours
    when 7.0..8.0
      20
    when 6.0..6.9, 8.1..9.0
      15
    when 5.0..5.9, 9.1..10.0
      10
    else
      5
    end

    # 気分スコア
    mood_bonus = (mood_score - 5) * 2 # -5から5の範囲を-10から10に変換

    # 疲労感スコア（疲労感が少ないほど高スコア）
    fatigue_bonus = (10 - fatigue_score) * 1.5

    # 症状数による減点
    symptom_penalty = symptom_count * 5

    # 総合スコア計算
    total_score = [ base_score + sleep_score + mood_bonus + fatigue_bonus - symptom_penalty, 100 ].min
    total_score = [ total_score, 0 ].max

    # メモ（気分と疲労感を考慮）
    notes = case [ mood_score, fatigue_score ]
    in [ 7..8, 1..4 ]
      "仕事が順調に進みました。疲れも少なく快調です。"
    in [ 5..6, 3..6 ]
      "普通の一日でした。"
    in [ 4..5, 6..8 ]
      "少し疲れました。"
    else
      "普通の一日でした。"
    end

    # デフォルトの都道府県（東京都）を取得
    default_prefecture = Prefecture.find_by(code: '13')

    daily_log = DailyLog.create!(
      user: bob,
      prefecture: default_prefecture,
      date: date,
      sleep_hours: sleep_hours,
      mood: mood_score - 5, # moodは-5から5の範囲なので変換
      fatigue: fatigue_score - 5, # fatigueは-5から5の範囲なので変換
      memo: notes,
      score: total_score
    )

    # 天候データを別テーブルに保存
    WeatherObservation.create!(
      daily_log: daily_log,
      temperature_c: temperature,
      humidity_pct: humidity,
      pressure_hpa: pressure,
      observed_at: date.to_datetime,
      snapshot: {
        weather_condition: weather_condition
      }
    )

    # 症状を関連付け
    selected_symptoms.each do |symptom_code|
      symptom = Symptom.find_by(code: symptom_code)
      if symptom
        DailyLogSymptom.create!(
          daily_log: daily_log,
          symptom: symptom
        )
      end
    end

    puts "  Created daily log for Bob on #{date}: sleep=#{sleep_hours}h, mood=#{mood_score}, fatigue=#{fatigue_score}, score=#{total_score}, symptoms=#{selected_symptoms.join(', ')}"
  end
end

puts "Seed completed."
