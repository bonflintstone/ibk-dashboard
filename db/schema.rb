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

ActiveRecord::Schema[8.0].define(version: 2026_06_11_103426) do
  create_table "events", force: :cascade do |t|
    t.string "name"
    t.string "location"
    t.datetime "datetime"
    t.string "description"
    t.string "link"
    t.string "organization"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "approved_at"
    t.integer "source", default: 0
    t.string "category"
  end

  create_table "instagram_profiles", force: :cascade do |t|
    t.string "username", null: false
    t.string "organization", null: false
    t.string "location", null: false
    t.string "posts_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["username"], name: "index_instagram_profiles_on_username", unique: true
  end

  create_table "refetch_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "new_event_count"
  end

  create_table "scraper_runs", force: :cascade do |t|
    t.string "scraper", null: false
    t.integer "status", default: 0, null: false
    t.string "error_class"
    t.text "error_message"
    t.integer "events_count"
    t.integer "duration_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scraper", "created_at"], name: "index_scraper_runs_on_scraper_and_created_at"
  end

  create_table "visits", force: :cascade do |t|
    t.date "week", null: false
    t.string "visitor_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["week", "visitor_digest"], name: "index_visits_on_week_and_visitor_digest", unique: true
  end
end
