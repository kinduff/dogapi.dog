# frozen_string_literal: true

class CreateBreedImages < ActiveRecord::Migration[8.1]
  def change
    create_table :breed_images, id: :uuid do |t|
      t.references :breed, null: false, foreign_key: true, type: :uuid
      t.integer :position, null: false, default: 0

      # Where the file came from, so an import can be re-run without creating
      # duplicates and so the licence can be traced back to its origin.
      t.string :source, null: false
      t.string :source_id, null: false
      t.string :source_url, null: false
      t.string :page_url

      # Attribution. Every image this API serves is under a licence that
      # requires crediting the author, so these travel with the payload.
      t.string :author
      t.string :license, null: false
      t.string :license_url

      t.timestamps
    end

    add_index :breed_images, %i[breed_id position]
    add_index :breed_images, %i[source source_id], unique: true
  end
end
