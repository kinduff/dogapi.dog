# frozen_string_literal: true

# The gem is loaded on demand, and a review run is the first thing here to
# need it.
require "anthropic"

# Imports pictures of breeds from external sources into Active Storage.
module BreedImages
  SOURCES = {
    "wikipedia_lead" => "BreedImages::WikipediaLead",
    "wikipedia_article" => "BreedImages::WikipediaArticle",
    "commons_category" => "BreedImages::CommonsCategory",
    "wikimedia_commons" => "BreedImages::WikimediaCommons",
    "openverse" => "BreedImages::Openverse",
    "manual" => "BreedImages::Manual"
  }.freeze

  # In order of how much human judgement went into the pictures they return:
  # the one photo an article was built around, then a category somebody filed
  # files into, then a full text search, then everything Flickr has. A breed
  # short of images is walked down this list until it has enough.
  SOURCE_ORDER = %w[wikipedia_lead wikipedia_article commons_category wikimedia_commons openverse].freeze

  DEFAULT_SOURCE = "wikipedia_lead"

  # What a review run asks the model for, and where it stops caring.
  DEFAULT_REVIEW_MODEL = "claude-opus-5"

  class Error < StandardError; end

  class << self
    def adapter_for(source)
      class_name = SOURCES.fetch(source.to_s) do
        raise ArgumentError, "unknown image source #{source.inspect}, expected one of #{SOURCES.keys.join(", ")}"
      end

      class_name.constantize
    end

    # Wikimedia's API policy asks for an agent that identifies the client and a
    # way to reach whoever runs it.
    def user_agent
      contact = ENV.fetch("IMAGE_IMPORT_CONTACT", "https://dogapi.dog")

      "dogapi.dog breed image importer (#{contact})"
    end

    # Read at call time rather than at boot, so a rake task can point a review
    # run at a different model without touching the code.
    def review_model = ENV.fetch("IMAGE_REVIEW_MODEL", DEFAULT_REVIEW_MODEL)

    def review_client
      raise Error, "ANTHROPIC_API_KEY is not set" if ENV["ANTHROPIC_API_KEY"].blank?

      Anthropic::Client.new
    end
  end
end
