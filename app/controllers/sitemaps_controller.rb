# frozen_string_literal: true

# The list of everything worth crawling: the static pages, the breed pages and
# the group pages. Small enough to build on request and cache for an hour.
class SitemapsController < ApplicationController
  CACHE_KEY = "sitemap/urls"
  CACHE_TTL = 1.hour

  # The pages that are not a record. The listing ones move whenever the data
  # behind them does, so they carry the date of the newest record; the rest
  # only change when the site itself is edited, and say nothing.
  DATA_BACKED_PATHS = ["/", "/breeds", "/groups"].freeze
  STATIC_PATHS = ["/docs", "/docs/api-v1", "/docs/api-v2", "/terms"].freeze

  def show
    @urls = urls

    respond_to do |format|
      format.xml
    end
  end

  private

  def urls
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      data_backed = DATA_BACKED_PATHS.map { |path| {loc: path, lastmod: newest_record&.iso8601} }
      static = STATIC_PATHS.map { |path| {loc: path, lastmod: nil} }

      data_backed + static + breed_urls + group_urls
    end
  end

  def newest_record
    [Breed.maximum(:updated_at), Group.maximum(:updated_at)].compact.max
  end

  def breed_urls
    Breed.order(:name).pluck(:name, :id, :updated_at).map do |name, id, updated_at|
      {loc: "/breeds/#{name.parameterize.presence || id}", lastmod: updated_at&.iso8601}
    end
  end

  def group_urls
    Group.order(:name).pluck(:name, :id, :updated_at).map do |name, id, updated_at|
      {loc: "/groups/#{name.parameterize.presence || id}", lastmod: updated_at&.iso8601}
    end
  end
end
