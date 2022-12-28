# frozen_string_literal: true

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

ActiveRecord::Schema[7.0].define(version: 20_221_228_161_853) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'pgcrypto'
  enable_extension 'plpgsql'

  create_table 'active_storage_attachments', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.string 'name', null: false
    t.string 'record_type', null: false
    t.uuid 'record_id', null: false
    t.uuid 'blob_id', null: false
    t.datetime 'created_at', null: false
    t.index ['blob_id'], name: 'index_active_storage_attachments_on_blob_id'
    t.index %w[record_type record_id name blob_id], name: 'index_active_storage_attachments_uniqueness', unique: true
  end

  create_table 'active_storage_blobs', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.string 'key', null: false
    t.string 'filename', null: false
    t.string 'content_type'
    t.text 'metadata'
    t.string 'service_name', null: false
    t.bigint 'byte_size', null: false
    t.string 'checksum'
    t.datetime 'created_at', null: false
    t.index ['key'], name: 'index_active_storage_blobs_on_key', unique: true
  end

  create_table 'active_storage_variant_records', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'blob_id', null: false
    t.string 'variation_digest', null: false
    t.index %w[blob_id variation_digest], name: 'index_active_storage_variant_records_uniqueness', unique: true
  end

  create_table 'ahoy_events', force: :cascade do |t|
    t.bigint 'visit_id'
    t.string 'name'
    t.jsonb 'properties'
    t.datetime 'time'
    t.index %w[name time], name: 'index_ahoy_events_on_name_and_time'
    t.index ['properties'], name: 'index_ahoy_events_on_properties', opclass: :jsonb_path_ops, using: :gin
    t.index ['visit_id'], name: 'index_ahoy_events_on_visit_id'
  end

  create_table 'ahoy_visits', force: :cascade do |t|
    t.string 'visit_token'
    t.string 'visitor_token'
    t.string 'ip'
    t.text 'user_agent'
    t.text 'referrer'
    t.string 'referring_domain'
    t.text 'landing_page'
    t.string 'browser'
    t.string 'os'
    t.string 'device_type'
    t.string 'country'
    t.string 'region'
    t.string 'city'
    t.float 'latitude'
    t.float 'longitude'
    t.string 'utm_source'
    t.string 'utm_medium'
    t.string 'utm_term'
    t.string 'utm_content'
    t.string 'utm_campaign'
    t.string 'app_version'
    t.string 'os_version'
    t.string 'platform'
    t.datetime 'started_at'
    t.index ['visit_token'], name: 'index_ahoy_visits_on_visit_token', unique: true
  end

  create_table 'breeds', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.string 'name'
    t.text 'description'
    t.jsonb 'life', default: '{}', null: false
    t.jsonb 'male_weight', default: '{}', null: false
    t.jsonb 'female_weight', default: '{}', null: false
    t.uuid 'group_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.boolean 'hypoallergenic', default: false
    t.index ['group_id'], name: 'index_breeds_on_group_id'
  end

  create_table 'facts', force: :cascade do |t|
    t.uuid 'uuid', default: -> { 'gen_random_uuid()' }, null: false
    t.text 'body'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  create_table 'groups', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.string 'name'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  create_table 'users', force: :cascade do |t|
    t.string 'username'
    t.string 'password_digest'
    t.string 'remember_token'
    t.datetime 'remember_token_expires_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  add_foreign_key 'active_storage_attachments', 'active_storage_blobs', column: 'blob_id'
  add_foreign_key 'active_storage_variant_records', 'active_storage_blobs', column: 'blob_id'
  add_foreign_key 'breeds', 'groups'
end
