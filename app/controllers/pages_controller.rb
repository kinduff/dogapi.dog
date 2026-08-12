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

  def demo
  end

  # A gallery of everything the image importer has stored, and of everything it
  # has not: the gaps are the point of the page as much as the pictures.
  def images
    @filter = FILTERS.include?(params[:filter]) ? params[:filter] : "all"
    @stats = image_stats
    @breeds = filtered_breeds
  end

  def api_v1
    @document = OpenapiDocument.load("v1")
  end

  def api_v2
    @document = OpenapiDocument.load("v2")
  end

  private

  FILTERS = %w[all with missing].freeze
  IMAGE_STATS_CACHE_KEY = "images/stats"
  IMAGE_STATS_CACHE_TTL = 10.minutes

  def filtered_breeds
    scope = Breed.includes(:group, breed_images: {file_attachment: {blob: {variant_records: {image_attachment: :blob}}}})

    case @filter
    when "with" then scope.where.associated(:breed_images).distinct.order(:name)
    when "missing" then scope.where.missing(:breed_images).order(:name)
    else scope.order(:name)
    end
  end

  # Coverage overall and per group, so it is obvious which corner of the
  # collection the next import run should go after.
  def image_stats
    Rails.cache.fetch(IMAGE_STATS_CACHE_KEY, expires_in: IMAGE_STATS_CACHE_TTL) do
      breeds = Breed.count
      covered = Breed.where.associated(:breed_images).distinct.count

      {
        breeds: breeds,
        covered: covered,
        missing: breeds - covered,
        images: BreedImage.count,
        licenses: BreedImage.group(:license).order(count_all: :desc).count,
        groups: group_coverage
      }
    end
  end

  def group_coverage
    totals = Breed.group(:group_id).count
    covered = Breed.where.associated(:breed_images).group(:group_id).distinct.count

    Group.order(:name).map do |group|
      {name: group.name, total: totals.fetch(group.id, 0), covered: covered.fetch(group.id, 0)}
    end
  end

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
