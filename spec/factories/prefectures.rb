FactoryBot.define do
  factory :prefecture do
    sequence(:code) { |n| sprintf("%02d", n) }
    sequence(:name_ja) { |n| "都道府県#{n}" }
    centroid_lat { Faker::Address.latitude }
    centroid_lon { Faker::Address.longitude }

    trait :tokyo do
      code { "13" }
      name_ja { "東京都" }
      centroid_lat { 35.6762 }
      centroid_lon { 139.6503 }
    end

    trait :osaka do
      code { "27" }
      name_ja { "大阪府" }
      centroid_lat { 34.6937 }
      centroid_lon { 135.5023 }
    end
  end
end
