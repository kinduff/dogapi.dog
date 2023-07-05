# frozen_string_literal: true

class Fact < ApplicationRecord
  include PgSearch::Model
  pg_search_scope :search_by_body, against: :body, using: {tsearch: {prefix: true}}
end
