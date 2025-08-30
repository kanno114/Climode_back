puts "Seeding users..."

users = [
  { name: "Alice", email: "alice@example.com", password: "password123", password_confirmation: "password123" },
  { name: "Bob", email: "bob@example.com", password: "password123", password_confirmation: "password123" },
  { name: "Carol", email: "carol@example.com", password: "password123", password_confirmation: "password123" },
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

# 症状マスタデータ
symptoms_data = [
  { code: 'headache', name: '頭痛' },
  { code: 'fatigue', name: '疲労感' },
  { code: 'dizziness', name: 'めまい' },
  { code: 'nausea', name: '吐き気' },
  { code: 'joint_pain', name: '関節痛' },
  { code: 'muscle_pain', name: '筋肉痛' },
  { code: 'back_pain', name: '腰痛' },
  { code: 'shoulder_pain', name: '肩こり' },
  { code: 'eye_strain', name: '目の疲れ' },
  { code: 'insomnia', name: '不眠' },
  { code: 'oversleeping', name: '過眠' },
  { code: 'irritability', name: 'イライラ' },
  { code: 'anxiety', name: '不安感' },
  { code: 'depression', name: '憂鬱感' },
  { code: 'loss_of_appetite', name: '食欲不振' },
  { code: 'overeating', name: '過食' },
  { code: 'stomach_ache', name: '腹痛' },
  { code: 'diarrhea', name: '下痢' },
  { code: 'constipation', name: '便秘' },
  { code: 'runny_nose', name: '鼻水' },
  { code: 'sneezing', name: 'くしゃみ' },
  { code: 'itchy_eyes', name: '目のかゆみ' },
  { code: 'skin_rash', name: '発疹' },
  { code: 'swelling', name: 'むくみ' }
]

symptoms_data.each do |symptom_data|
  Symptom.find_or_create_by!(code: symptom_data[:code]) do |symptom|
    symptom.name = symptom_data[:name]
  end
end

puts "Seed completed."
