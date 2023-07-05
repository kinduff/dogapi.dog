# frozen_string_literal: true

class Group < ApplicationRecord
  include PgSearch::Model
  pg_search_scope :search_by_name, against: :name, using: {tsearch: {prefix: true}}

  has_many :breeds
end
