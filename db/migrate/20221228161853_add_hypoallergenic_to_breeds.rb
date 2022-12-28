# frozen_string_literal: true

class AddHypoallergenicToBreeds < ActiveRecord::Migration[7.0]
  def change
    add_column :breeds, :hypoallergenic, :boolean, default: false
  end
end
