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

ActiveRecord::Schema[7.2].define(version: 2025_09_22_085511) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "parking_rules", force: :cascade do |t|
    t.bigint "street_section_id", null: false
    t.time "start_time"
    t.time "end_time"
    t.string "day_of_week"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "start_date"
    t.date "end_date"
    t.integer "day_of_month"
    t.string "even_odd"
    t.jsonb "ordinal"
    t.index ["street_section_id"], name: "index_parking_rules_on_street_section_id"
  end

  create_table "parking_spots", force: :cascade do |t|
    t.jsonb "coordinates"
    t.string "side_of_street"
    t.jsonb "address"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active"
    t.geography "geometry", limit: {:srid=>4326, :type=>"st_point", :geographic=>true}
    t.index ["user_id"], name: "index_parking_spots_on_user_id"
  end

  create_table "street_sections", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.jsonb "coordinates"
    t.jsonb "address"
    t.string "street_direction"
    t.string "side_of_street"
    t.jsonb "center"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.geometry "geometry", limit: {:srid=>4326, :type=>"line_string"}
    t.index ["user_id"], name: "index_street_sections_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "jti"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "parking_rules", "street_sections"
  add_foreign_key "parking_spots", "users"
  add_foreign_key "street_sections", "users"
end
