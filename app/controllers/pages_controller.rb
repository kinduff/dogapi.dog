# frozen_string_literal: true

class PagesController < ApplicationController
  SAMPLE_ID_CACHE_KEY = "docs/sample_ids"
  SAMPLE_ID_CACHE_TTL = 1.hour
  COUNTS_CACHE_KEY = "home/counts"
  COUNTS_CACHE_TTL = 1.hour

  helper_method :sample_ids

  def index
    @fact = Fact.random.first
    @counts = data_counts
  end

  def terms
  end

  def docs
  end

  def api_v1
    @document = OpenapiDocument.load("v1")
  end

  def api_v2
    @document = OpenapiDocument.load("v2")
  end

  private

  # What the API holds right now, for the homepage. Counting three small tables
  # once an hour is cheaper than keeping a number in the copy that goes stale.
  def data_counts
    Rails.cache.fetch(COUNTS_CACHE_KEY, expires_in: COUNTS_CACHE_TTL) do
      {breeds: Breed.count, groups: Group.count, facts: Fact.count}
    end
  end

  # Ids of records that actually exist, so the examples and the prefilled
  # try-it fields resolve instead of 404ing. Cached because the docs pages are
  # the only caller and the answer barely changes.
  def sample_ids
    Rails.cache.fetch(SAMPLE_ID_CACHE_KEY, expires_in: SAMPLE_ID_CACHE_TTL) do
      {
        "breed" => Breed.order(:name).pick(:id),
        "group" => Group.order(:name).pick(:id)
      }
    end
  end
end
