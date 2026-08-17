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

ActiveRecord::Schema[8.1].define(version: 2025_12_31_000919) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"

  create_table "alerts", force: :cascade do |t|
    t.datetime "alert_time"
    t.datetime "created_at", null: false
    t.datetime "enqueued_at"
    t.bigint "parking_rule_id", null: false
    t.bigint "parking_spot_id", null: false
    t.datetime "rule_start_time"
    t.boolean "sent"
    t.datetime "sent_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["parking_rule_id"], name: "index_alerts_on_parking_rule_id"
    t.index ["parking_spot_id"], name: "index_alerts_on_parking_spot_id"
    t.index ["user_id"], name: "index_alerts_on_user_id"
  end

  create_table "parking_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_of_month"
    t.string "day_of_week"
    t.date "end_date"
    t.time "end_time"
    t.string "even_odd"
    t.jsonb "ordinal"
    t.date "start_date"
    t.time "start_time"
    t.bigint "street_section_id", null: false
    t.datetime "updated_at", null: false
    t.index ["street_section_id"], name: "index_parking_rules_on_street_section_id"
  end

  create_table "parking_spots", force: :cascade do |t|
    t.boolean "active"
    t.jsonb "address"
    t.jsonb "coordinates"
    t.datetime "created_at", null: false
    t.geography "geometry", limit: {srid: 4326, type: "st_point", geographic: true}
    t.string "side_of_street"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_parking_spots_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth_key"
    t.datetime "created_at", null: false
    t.string "device_token"
    t.text "endpoint"
    t.string "p256dh_key"
    t.string "platform"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["device_token"], name: "index_push_subscriptions_on_device_token", unique: true
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
  end

  create_table "street_sections", force: :cascade do |t|
    t.jsonb "address"
    t.jsonb "center"
    t.jsonb "coordinates"
    t.datetime "created_at", null: false
    t.geometry "geometry", limit: {srid: 4326, type: "line_string"}
    t.string "side_of_street"
    t.string "street_direction"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_street_sections_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "jti", null: false
    t.string "name"
    t.integer "notification_lead_time_hours"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "alerts", "parking_rules"
  add_foreign_key "alerts", "parking_spots"
  add_foreign_key "alerts", "users"
  add_foreign_key "parking_rules", "street_sections"
  add_foreign_key "parking_spots", "users"
  add_foreign_key "street_sections", "users"
end
