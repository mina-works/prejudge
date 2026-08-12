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

ActiveRecord::Schema[7.1].define(version: 2026_08_05_074225) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "artifact_reviewers", force: :cascade do |t|
    t.integer "artifact_id", null: false
    t.integer "user_id", null: false
    t.integer "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artifact_id", "user_id"], name: "index_artifact_reviewers_on_artifact_id_and_user_id", unique: true
    t.index ["artifact_id"], name: "index_artifact_reviewers_on_artifact_id"
    t.index ["user_id"], name: "index_artifact_reviewers_on_user_id"
  end

  create_table "artifacts", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.integer "creator_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "current_round", default: 1, null: false
    t.datetime "review_deadline"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_artifacts_on_creator_id"
  end

  create_table "review_conditions", force: :cascade do |t|
    t.integer "artifact_id", null: false
    t.text "purpose", null: false
    t.integer "target", null: false
    t.integer "tone", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artifact_id"], name: "index_review_conditions_on_artifact_id"
  end

  create_table "review_issues", force: :cascade do |t|
    t.integer "review_id", null: false
    t.integer "issue_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id"], name: "index_review_issues_on_review_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.integer "artifact_id", null: false
    t.integer "user_id", null: false
    t.integer "result", null: false
    t.integer "round", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artifact_id", "user_id", "round"], name: "index_reviews_on_artifact_id_and_user_id_and_round", unique: true
    t.index ["artifact_id"], name: "index_reviews_on_artifact_id"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.boolean "active", default: true, null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "artifact_reviewers", "artifacts"
  add_foreign_key "artifact_reviewers", "users"
  add_foreign_key "artifacts", "users", column: "creator_id"
  add_foreign_key "review_conditions", "artifacts"
  add_foreign_key "review_issues", "reviews"
  add_foreign_key "reviews", "artifacts"
  add_foreign_key "reviews", "users"
end
