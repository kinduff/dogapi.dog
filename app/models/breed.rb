# frozen_string_literal: true

class Breed < ApplicationRecord
  belongs_to :group
  has_many :breed_images, -> { ordered }, dependent: :destroy, inverse_of: :breed

  # The lowest positioned image, which is what a single-image response uses.
  def primary_image
    breed_images.first
  end

  store_accessor :life, :min, :max, prefix: true
  store_accessor :female_weight, :min, :max, prefix: true
  store_accessor :male_weight, :min, :max, prefix: true
end
