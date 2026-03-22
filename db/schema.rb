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

ActiveRecord::Schema[8.1].define(version: 2026_03_16_100004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "event_daily_rollups", force: :cascade do |t|
    t.integer "count", default: 0, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "event_name", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "event_name", "date"], name: "idx_rollups_project_event_date", unique: true
    t.index ["project_id"], name: "index_event_daily_rollups_on_project_id"
  end

  create_table "events", primary_key: ["id", "occurred_at"], options: "PARTITION BY RANGE (occurred_at)", force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.bigserial "id", null: false
    t.string "idempotency_key"
    t.string "name", null: false
    t.datetime "occurred_at", precision: nil, null: false
    t.bigint "project_id", null: false
    t.jsonb "properties", default: {}, null: false
    t.bigint "user_profile_id"
    t.index ["project_id", "idempotency_key", "occurred_at"], name: "idx_events_idempotency", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["project_id", "name", "occurred_at"], name: "idx_events_project_name_time"
    t.index ["project_id", "user_profile_id", "occurred_at"], name: "idx_events_project_user_time"
    t.index ["properties"], name: "idx_events_properties", using: :gin
  end

  create_table "events_y2026m02", primary_key: ["id", "occurred_at"], options: "INHERITS (events)", force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.bigint "id", default: -> { "nextval('events_id_seq'::regclass)" }, null: false
    t.string "idempotency_key"
    t.string "name", null: false
    t.datetime "occurred_at", precision: nil, null: false
    t.bigint "project_id", null: false
    t.jsonb "properties", default: {}, null: false
    t.bigint "user_profile_id"
    t.index ["project_id", "idempotency_key", "occurred_at"], name: "events_y2026m02_project_id_idempotency_key_occurred_at_idx", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["project_id", "name", "occurred_at"], name: "events_y2026m02_project_id_name_occurred_at_idx"
    t.index ["project_id", "user_profile_id", "occurred_at"], name: "events_y2026m02_project_id_user_profile_id_occurred_at_idx"
    t.index ["properties"], name: "events_y2026m02_properties_idx", using: :gin
  end

  create_table "events_y2026m03", primary_key: ["id", "occurred_at"], options: "INHERITS (events)", force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.bigint "id", default: -> { "nextval('events_id_seq'::regclass)" }, null: false
    t.string "idempotency_key"
    t.string "name", null: false
    t.datetime "occurred_at", precision: nil, null: false
    t.bigint "project_id", null: false
    t.jsonb "properties", default: {}, null: false
    t.bigint "user_profile_id"
    t.index ["project_id", "idempotency_key", "occurred_at"], name: "events_y2026m03_project_id_idempotency_key_occurred_at_idx", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["project_id", "name", "occurred_at"], name: "events_y2026m03_project_id_name_occurred_at_idx"
    t.index ["project_id", "user_profile_id", "occurred_at"], name: "events_y2026m03_project_id_user_profile_id_occurred_at_idx"
    t.index ["properties"], name: "events_y2026m03_properties_idx", using: :gin
  end

  create_table "events_y2026m04", primary_key: ["id", "occurred_at"], options: "INHERITS (events)", force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.bigint "id", default: -> { "nextval('events_id_seq'::regclass)" }, null: false
    t.string "idempotency_key"
    t.string "name", null: false
    t.datetime "occurred_at", precision: nil, null: false
    t.bigint "project_id", null: false
    t.jsonb "properties", default: {}, null: false
    t.bigint "user_profile_id"
    t.index ["project_id", "idempotency_key", "occurred_at"], name: "events_y2026m04_project_id_idempotency_key_occurred_at_idx", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["project_id", "name", "occurred_at"], name: "events_y2026m04_project_id_name_occurred_at_idx"
    t.index ["project_id", "user_profile_id", "occurred_at"], name: "events_y2026m04_project_id_user_profile_id_occurred_at_idx"
    t.index ["properties"], name: "events_y2026m04_properties_idx", using: :gin
  end

  create_table "events_y2026m05", primary_key: ["id", "occurred_at"], options: "INHERITS (events)", force: :cascade do |t|
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.bigint "id", default: -> { "nextval('events_id_seq'::regclass)" }, null: false
    t.string "idempotency_key"
    t.string "name", null: false
    t.datetime "occurred_at", precision: nil, null: false
    t.bigint "project_id", null: false
    t.jsonb "properties", default: {}, null: false
    t.bigint "user_profile_id"
    t.index ["project_id", "idempotency_key", "occurred_at"], name: "events_y2026m05_project_id_idempotency_key_occurred_at_idx", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["project_id", "name", "occurred_at"], name: "events_y2026m05_project_id_name_occurred_at_idx"
    t.index ["project_id", "user_profile_id", "occurred_at"], name: "events_y2026m05_project_id_user_profile_id_occurred_at_idx"
    t.index ["properties"], name: "events_y2026m05_properties_idx", using: :gin
  end

  create_table "identity_aliases", force: :cascade do |t|
    t.string "anonymous_id", null: false
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.bigint "user_profile_id", null: false
    t.index ["project_id", "anonymous_id"], name: "index_identity_aliases_on_project_id_and_anonymous_id", unique: true
    t.index ["project_id"], name: "index_identity_aliases_on_project_id"
    t.index ["user_profile_id"], name: "index_identity_aliases_on_user_profile_id"
  end

  create_table "project_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.string "role", default: "viewer", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id"], name: "index_project_memberships_on_project_id"
    t.index ["user_id", "project_id"], name: "index_project_memberships_on_user_id_and_project_id", unique: true
    t.index ["user_id"], name: "index_project_memberships_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "api_key", null: false
    t.string "api_secret", null: false
    t.datetime "created_at", null: false
    t.integer "events_count", default: 0
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["api_key"], name: "index_projects_on_api_key", unique: true
    t.index ["api_secret"], name: "index_projects_on_api_secret", unique: true
  end

  create_table "saved_reports", force: :cascade do |t|
    t.jsonb "configuration", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.string "report_type", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "report_type"], name: "index_saved_reports_on_project_id_and_report_type"
    t.index ["project_id"], name: "index_saved_reports_on_project_id"
  end

  create_table "segments", force: :cascade do |t|
    t.jsonb "conditions", default: [], null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_segments_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_segments_on_project_id"
  end

  create_table "user_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.datetime "first_seen_at"
    t.datetime "last_seen_at"
    t.bigint "project_id", null: false
    t.jsonb "properties", default: {}
    t.datetime "updated_at", null: false
    t.index ["project_id", "external_id"], name: "index_user_profiles_on_project_id_and_external_id", unique: true
    t.index ["project_id"], name: "index_user_profiles_on_project_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "webhooks", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.jsonb "event_names", default: [], null: false
    t.integer "failures", default: 0, null: false
    t.datetime "last_triggered_at"
    t.bigint "project_id", null: false
    t.string "secret"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["project_id", "active"], name: "index_webhooks_on_project_id_and_active"
    t.index ["project_id"], name: "index_webhooks_on_project_id"
  end

  add_foreign_key "event_daily_rollups", "projects"
  add_foreign_key "events", "projects", name: "fk_events_project"
  add_foreign_key "events_y2026m02", "projects", name: "fk_events_project"
  add_foreign_key "events_y2026m03", "projects", name: "fk_events_project"
  add_foreign_key "events_y2026m04", "projects", name: "fk_events_project"
  add_foreign_key "events_y2026m05", "projects", name: "fk_events_project"
  add_foreign_key "identity_aliases", "projects"
  add_foreign_key "identity_aliases", "user_profiles"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
  add_foreign_key "saved_reports", "projects"
  add_foreign_key "segments", "projects"
  add_foreign_key "user_profiles", "projects"
  add_foreign_key "webhooks", "projects"
end
