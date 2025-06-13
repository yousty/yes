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

ActiveRecord::Schema[7.2].define(version: 2024_03_21_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "shared_profile_read_models", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "birth_date"
    t.string "phone_number"
    t.string "address"
    t.string "city"
    t.string "country"
    t.string "postal_code"
    t.integer "test_personal_info_revision", default: -1, null: false
    t.integer "test_contact_info_revision", default: -1, null: false
    t.string "locale"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_shared_profile_read_models_on_email"
  end

  create_table "test_locations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "revision", default: -1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "test_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.integer "age"
    t.boolean "active"
    t.string "document_ids"
    t.string "another"
    t.string "test_field"
    t.uuid "location_id"
    t.string "shortcut_description"
    t.integer "shortcuts_used"
    t.boolean "shortcut_usage_enabled"
    t.boolean "shortcut_toggle"
    t.boolean "published"
    t.string "locale_test"
    t.integer "revision", default: -1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
