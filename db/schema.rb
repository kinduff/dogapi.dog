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

ActiveRecord::Schema[8.1].define(version: 2026_08_13_044700) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "breed_enrichments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "applied_at"
    t.uuid "breed_id", null: false
    t.string "confidence"
    t.datetime "created_at", null: false
    t.string "model", null: false
    t.jsonb "payload", default: {}, null: false
    t.jsonb "raw_response", default: {}, null: false
    t.jsonb "rejections", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["breed_id", "created_at"], name: "index_breed_enrichments_on_breed_id_and_created_at"
    t.index ["breed_id"], name: "index_breed_enrichments_on_breed_id"
  end

  create_table "breed_images", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "author"
    t.uuid "breed_id", null: false
    t.datetime "created_at", null: false
    t.string "license", null: false
    t.string "license_url"
    t.string "page_url"
    t.integer "position", default: 0, null: false
    t.string "source", null: false
    t.string "source_id", null: false
    t.string "source_url", null: false
    t.datetime "updated_at", null: false
    t.index ["breed_id", "position"], name: "index_breed_images_on_breed_id_and_position"
    t.index ["breed_id"], name: "index_breed_images_on_breed_id"
    t.index ["source", "source_id"], name: "index_breed_images_on_source_and_source_id", unique: true
  end

  create_table "breeds", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "coat", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "enriched_at"
    t.string "enrichment_model"
    t.jsonb "female_height", default: {}, null: false
    t.jsonb "female_weight", default: {}, null: false
    t.uuid "group_id", null: false
    t.boolean "hypoallergenic", default: false
    t.jsonb "life", default: {}, null: false
    t.jsonb "male_height", default: {}, null: false
    t.jsonb "male_weight", default: {}, null: false
    t.string "name"
    t.jsonb "origin", default: {}, null: false
    t.string "other_names", default: [], null: false, array: true
    t.string "recognized_by", default: [], null: false, array: true
    t.jsonb "sources", default: [], null: false
    t.jsonb "traits", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["enriched_at"], name: "index_breeds_on_enriched_at"
    t.index ["group_id"], name: "index_breeds_on_group_id"
    t.index ["name"], name: "index_breeds_on_name"
  end

  create_table "facts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["uuid"], name: "index_facts_on_uuid", unique: true
  end

  create_table "groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_groups_on_name"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "breed_enrichments", "breeds"
  add_foreign_key "breed_images", "breeds"
  add_foreign_key "breeds", "groups"
end
