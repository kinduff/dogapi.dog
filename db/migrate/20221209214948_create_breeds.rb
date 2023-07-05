# frozen_string_literal: true

class CreateBreeds < ActiveRecord::Migration[7.0]
  def change
    create_table :breeds, id: :uuid do |t|
      t.string :name
      t.text :description
      t.jsonb :life, null: false, default: "{}"
      t.jsonb :male_weight, null: false, default: "{}"
      t.jsonb :female_weight, null: false, default: "{}"
      t.references :group, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
