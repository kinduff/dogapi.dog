# frozen_string_literal: true

class CreateFacts < ActiveRecord::Migration[7.0]
  def change
    create_table :facts do |t|
      t.uuid :uuid, default: "gen_random_uuid()", null: false
      t.text :body

      t.timestamps
    end
  end
end
