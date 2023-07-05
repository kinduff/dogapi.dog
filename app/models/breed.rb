# frozen_string_literal: true

class Breed < ApplicationRecord
  include PgSearch::Model
  pg_search_scope :search_by_name, against: :name, using: {tsearch: {prefix: true}}

  belongs_to :group
  has_many_attached :images

  store_accessor :life, :min, :max, prefix: true
  store_accessor :female_weight, :min, :max, prefix: true
  store_accessor :male_weight, :min, :max, prefix: true
end
