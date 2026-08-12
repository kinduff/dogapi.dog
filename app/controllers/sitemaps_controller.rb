# frozen_string_literal: true

# The list of everything worth crawling: the static pages, the breed pages and
# the group pages. Small enough to build on request and cache for an hour.
class SitemapsController < ApplicationController
  CACHE_KEY = "sitemap/urls"
  CACHE_TTL = 1.hour

  STATIC_PATHS = {
    "/" => "daily",
    "/breeds" => "daily",
    "/groups" => "weekly",
    "/docs" => "weekly",
    "/docs/api-v1" => "monthly",
    "/docs/api-v2" => "monthly",
    "/terms" => "yearly"
  }.freeze

  def show
    @urls = urls

    respond_to do |format|
      format.xml
    end
  end

  private

  def urls
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      static = STATIC_PATHS.map { |path, frequency| {loc: path, changefreq: frequency, lastmod: nil} }

      static + breed_urls + group_urls
    end
  end

  def breed_urls
    Breed.order(:name).pluck(:name, :id, :updated_at).map do |name, id, updated_at|
      {loc: "/breeds/#{name.parameterize.presence || id}", changefreq: "monthly", lastmod: updated_at&.iso8601}
    end
  end

  def group_urls
    Group.order(:name).pluck(:name, :id, :updated_at).map do |name, id, updated_at|
      {loc: "/groups/#{name.parameterize.presence || id}", changefreq: "monthly", lastmod: updated_at&.iso8601}
    end
  end
end
