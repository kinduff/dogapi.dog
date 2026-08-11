# frozen_string_literal: true

class AddMissingIndexes < ActiveRecord::Migration[8.1]
  def change
    # `uuid` is the public id of a fact, serialized as the JSON:API `id`.
    add_index :facts, :uuid, unique: true

    # Both indexes are ordered on by the v2 index endpoints.
    add_index :breeds, :name
    add_index :groups, :name
  end
end
