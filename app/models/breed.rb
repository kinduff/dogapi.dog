# frozen_string_literal: true

class Breed < ApplicationRecord
  # Ratings an enrichment run fills in, all on the same 1 (lowest) to 5
  # (highest) scale so a client can render them without a per-trait legend.
  RATINGS = %i[
    energy
    trainability
    barking
    grooming
    shedding
    drooling
    good_with_children
    good_with_dogs
    good_with_strangers
    apartment_friendly
  ].freeze

  belongs_to :group
  has_many :breed_images, -> { ordered }, dependent: :destroy, inverse_of: :breed
  has_many :breed_enrichments, -> { ordered }, dependent: :destroy, inverse_of: :breed

  scope :enriched, -> { where.not(enriched_at: nil) }
  scope :unenriched, -> { where(enriched_at: nil) }

  # The lowest positioned image, which is what a single-image response uses.
  def primary_image
    breed_images.first
  end

  store_accessor :life, :min, :max, prefix: true
  store_accessor :female_weight, :min, :max, prefix: true
  store_accessor :male_weight, :min, :max, prefix: true
  store_accessor :female_height, :min, :max, prefix: true
  store_accessor :male_height, :min, :max, prefix: true

  store_accessor :origin, :country, :region, :era, prefix: true
  store_accessor :coat, :type, :length, :colors, prefix: true
  store_accessor :traits, *RATINGS, :exercise_minutes, :temperament, prefix: true
end
