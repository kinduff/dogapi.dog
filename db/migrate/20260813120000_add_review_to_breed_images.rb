# frozen_string_literal: true

# What a review run thought of a picture, kept alongside it so a ranking can be
# explained and rebuilt without downloading anything again.
class AddReviewToBreedImages < ActiveRecord::Migration[8.1]
  def change
    add_column :breed_images, :score, :integer
    add_column :breed_images, :review_notes, :string
    add_column :breed_images, :reviewed_at, :datetime

    add_index :breed_images, [:breed_id, :score]
  end
end
