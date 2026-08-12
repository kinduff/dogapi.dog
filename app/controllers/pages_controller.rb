# frozen_string_literal: true

class PagesController < ApplicationController
  SAMPLE_ID_CACHE_KEY = "docs/sample_ids"
  SAMPLE_ID_CACHE_TTL = 1.hour
  COUNTS_CACHE_KEY = "home/counts"
  COUNTS_CACHE_TTL = 1.hour
  HERO_CACHE_KEY = "home/hero_pages"
  HERO_CACHE_TTL = 1.hour
  # One screenful of dogs, and the page size the request under them asks for.
  HERO_SIZE = 8

  helper_method :sample_ids

  def index
    @fact = Fact.random.first
    @counts = data_counts
    @hero_pages = hero_pages
    @hero_page = rand(1..@hero_pages) if @hero_pages.positive?
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

  # What the API holds right now, for the homepage. Counting three small tables
  # once an hour is cheaper than keeping a number in the copy that goes stale.
  def data_counts
    Rails.cache.fetch(COUNTS_CACHE_KEY, expires_in: COUNTS_CACHE_TTL) do
      {breeds: Breed.count, groups: Group.count, facts: Fact.count, images: BreedImage.count}
    end
  end

  # How many pages of pictured breeds there are, which is what the shuffle
  # button picks from. Cached because only an import moves it.
  def hero_pages
    Rails.cache.fetch(HERO_CACHE_KEY, expires_in: HERO_CACHE_TTL) do
      (Breed.where.associated(:breed_images).distinct.count / HERO_SIZE.to_f).ceil
    end
  end

  # One page of the collection the request under the grid asks for, down to the
  # order and the offset: what the page renders and what that URL returns are
  # the same eight breeds. Drawn at random so a reload brings different dogs
  # before anybody presses the button.
  def hero_breeds
    return Breed.none if @hero_page.nil?

    Breed
      .where.associated(:breed_images)
      .distinct
      .includes(:group, breed_images: {file_attachment: {blob: {variant_records: {image_attachment: :blob}}}})
      .order(:name)
      .offset((@hero_page - 1) * HERO_SIZE)
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
