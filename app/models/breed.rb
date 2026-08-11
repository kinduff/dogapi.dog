# frozen_string_literal: true

class Breed < ApplicationRecord
  belongs_to :group
  has_many_attached :images

  store_accessor :life, :min, :max, prefix: true
  store_accessor :female_weight, :min, :max, prefix: true
  store_accessor :male_weight, :min, :max, prefix: true
end
