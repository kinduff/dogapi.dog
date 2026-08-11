# frozen_string_literal: true

class Fact < ApplicationRecord
  include PgSearch::Model

  IDS_CACHE_KEY = "facts/ids"
  IDS_CACHE_TTL = 1.hour

  pg_search_scope :search_by_body, against: :body, using: {tsearch: {prefix: true}}

  after_commit :expire_cached_ids, on: [:create, :destroy]

  # `ORDER BY RANDOM()` sorts the whole table on every request. Facts change
  # rarely, so the ids are cached and sampled in Ruby instead.
  def self.random(limit = 1)
    ids = cached_ids
    return none if ids.empty?

    where(id: ids.sample(limit))
  end

  def self.cached_ids
    Rails.cache.fetch(IDS_CACHE_KEY, expires_in: IDS_CACHE_TTL) { order(:id).pluck(:id) }
  end

  private

  def expire_cached_ids
    Rails.cache.delete(IDS_CACHE_KEY)
  end
end
