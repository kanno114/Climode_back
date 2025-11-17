# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_11_12_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "daily_log_symptoms", force: :cascade do |t|
    t.bigint "daily_log_id", null: false
    t.bigint "symptom_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_log_id"], name: "index_daily_log_symptoms_on_daily_log_id"
    t.index ["symptom_id"], name: "index_daily_log_symptoms_on_symptom_id"
  end

  create_table "daily_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "prefecture_id", null: false
    t.date "date", null: false
    t.decimal "sleep_hours", precision: 4, scale: 1
    t.integer "mood"
    t.integer "fatigue"
    t.integer "score"
    t.integer "self_score"
    t.text "memo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prefecture_id"], name: "index_daily_logs_on_prefecture_id"
    t.index ["user_id", "date"], name: "index_daily_logs_on_user_id_and_date", unique: true
    t.index ["user_id"], name: "index_daily_logs_on_user_id"
    t.check_constraint "fatigue >= '-5'::integer AND fatigue <= 5", name: "check_fatigue_range"
    t.check_constraint "mood >= '-5'::integer AND mood <= 5", name: "check_mood_range"
    t.check_constraint "score >= 0 AND score <= 100", name: "check_score_range"
    t.check_constraint "self_score >= 0 AND self_score <= 100", name: "check_self_score_range"
    t.check_constraint "sleep_hours >= 0::numeric AND sleep_hours <= 24::numeric", name: "check_sleep_hours_range"
  end

  create_table "prefectures", force: :cascade do |t|
    t.string "code", null: false
    t.string "name_ja", null: false
    t.decimal "centroid_lat", precision: 8, scale: 6
    t.decimal "centroid_lon", precision: 9, scale: 6
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_prefectures_on_code", unique: true
    t.check_constraint "centroid_lat >= '-90'::integer::numeric AND centroid_lat <= 90::numeric", name: "check_latitude_range"
    t.check_constraint "centroid_lon >= '-180'::integer::numeric AND centroid_lon <= 180::numeric", name: "check_longitude_range"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "endpoint", null: false
    t.string "p256dh_key", null: false
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id", "endpoint"], name: "index_push_subscriptions_on_user_id_and_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "symptoms", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_symptoms_on_code", unique: true
    t.index ["name"], name: "index_symptoms_on_name", unique: true
  end

  create_table "triggers", force: :cascade do |t|
    t.string "key", null: false
    t.string "label", null: false
    t.string "category", null: false
    t.boolean "is_active", default: true, null: false
    t.integer "version", null: false
    t.jsonb "rule", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_triggers_on_key", unique: true
    t.check_constraint "category::text = ANY (ARRAY['env'::character varying, 'body'::character varying]::text[])", name: "triggers_category_check"
  end

  create_table "user_identities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.string "email"
    t.string "display_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_user_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_user_identities_on_user_id"
  end

  create_table "user_triggers", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "trigger_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trigger_id"], name: "index_user_triggers_on_trigger_id"
    t.index ["user_id", "trigger_id"], name: "index_user_triggers_on_user_id_and_trigger_id", unique: true
    t.index ["user_id"], name: "index_user_triggers_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.string "image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "prefecture_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["prefecture_id"], name: "index_users_on_prefecture_id"
  end

  create_table "weather_observations", force: :cascade do |t|
    t.bigint "daily_log_id", null: false
    t.decimal "temperature_c", precision: 4, scale: 1
    t.decimal "humidity_pct", precision: 5, scale: 2
    t.decimal "pressure_hpa", precision: 6, scale: 1
    t.datetime "observed_at"
    t.jsonb "snapshot"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_log_id"], name: "index_weather_observations_on_daily_log_id"
    t.check_constraint "humidity_pct >= 0::numeric AND humidity_pct <= 100::numeric", name: "check_humidity_range"
    t.check_constraint "pressure_hpa >= 800::numeric AND pressure_hpa <= 1100::numeric", name: "check_pressure_range"
    t.check_constraint "temperature_c >= '-90'::integer::numeric AND temperature_c <= 60::numeric", name: "check_temperature_range"
  end

  add_foreign_key "daily_log_symptoms", "daily_logs"
  add_foreign_key "daily_log_symptoms", "symptoms"
  add_foreign_key "daily_logs", "prefectures"
  add_foreign_key "daily_logs", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "user_identities", "users"
  add_foreign_key "user_triggers", "triggers", on_delete: :restrict
  add_foreign_key "user_triggers", "users", on_delete: :restrict
  add_foreign_key "users", "prefectures"
  add_foreign_key "weather_observations", "daily_logs"
end
