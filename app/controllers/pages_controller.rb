# frozen_string_literal: true

class PagesController < ApplicationController
  SAMPLE_ID_CACHE_KEY = "docs/sample_ids"
  SAMPLE_ID_CACHE_TTL = 1.hour
  HERO_CACHE_KEY = "home/hero_count"
  HERO_CACHE_TTL = 1.hour
  # Six across, three down: one screenful of dogs.
  HERO_SIZE = 18

  helper_method :sample_ids

  def index
    @fact = Fact.random.first
    @counts = DataCounts.call
    @hero_breeds = hero_breeds
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

  # How many breeds have a picture. Cached because only an import moves it, and
  # the grid only needs it to pick where to start.
  def hero_count
    Rails.cache.fetch(HERO_CACHE_KEY, expires_in: HERO_CACHE_TTL) do
      Breed.where.associated(:breed_images).distinct.count
    end
  end

  # A screenful of pictured breeds, starting at a random offset so a reload
  # brings different dogs.
  def hero_breeds
    count = hero_count
    return Breed.none if count.zero?

    Breed
      .where.associated(:breed_images)
      .distinct
      .includes(breed_images: {file_attachment: {blob: {variant_records: {image_attachment: :blob}}}})
      .order(:name)
      .offset(rand([count - HERO_SIZE, 0].max + 1))
      .limit(HERO_SIZE)
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
