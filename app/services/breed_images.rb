# frozen_string_literal: true

# Imports pictures of breeds from external sources into Active Storage.
module BreedImages
  SOURCES = {
    "wikimedia_commons" => "BreedImages::WikimediaCommons",
    "manual" => "BreedImages::Manual"
  }.freeze

  DEFAULT_SOURCE = "wikimedia_commons"

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
  end
end
