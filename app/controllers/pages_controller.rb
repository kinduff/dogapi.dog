# frozen_string_literal: true

class PagesController < ApplicationController
  SAMPLE_ID_CACHE_KEY = "docs/sample_ids"
  SAMPLE_ID_CACHE_TTL = 1.hour
  COUNTS_CACHE_KEY = "home/counts"
  COUNTS_CACHE_TTL = 1.hour
  HERO_CACHE_KEY = "home/hero_pool"
  HERO_CACHE_TTL = 1.hour
  HERO_POOL_SIZE = 40

  helper_method :sample_ids

  def index
    @fact = Fact.random.first
    @counts = data_counts
    @hero_pool = hero_pool.sample(HERO_POOL_SIZE)
    @hero_breed = hero_breed
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
      {breeds: Breed.count, groups: Group.count, facts: Fact.count, images: BreedImage.count}
    end
  end

  # The breeds the picture at the top of the page can land on. Cached because
  # importing pictures is the only thing that moves it, and the page hands the
  # list to the shuffle button so a click costs no round trip to pick one.
  # Names travel with the ids because the page a breed lives at is built from
  # its name, and guessing that in the browser gets accents wrong.
  def hero_pool
    Rails.cache.fetch(HERO_CACHE_KEY, expires_in: HERO_CACHE_TTL) do
      Breed.where.associated(:breed_images).distinct.pluck(:id, :name)
    end
  end

  # The one the page opens on, drawn per request so a reload is a different
  # dog even before anybody presses the button.
  def hero_breed
    return if @hero_pool.empty?

    Breed.includes(:group).find_by(id: @hero_pool.sample.first)
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
