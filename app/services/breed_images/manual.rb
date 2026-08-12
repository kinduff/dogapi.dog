# frozen_string_literal: true

module BreedImages
  # Hand curated images, for breeds Commons covers badly or where a specific
  # photo is wanted. Entries live in db/seeds/breed_images.yml:
  #
  #   Akita:
  #     - url: https://example.com/akita.jpg
  #       id: akita-1                       # optional, defaults to the url
  #       author: Jane Photographer
  #       license: CC BY 4.0
  #       license_url: https://creativecommons.org/licenses/by/4.0/
  #       page_url: https://example.com/photos/akita
  class Manual
    SOURCE = "manual"
    CATALOG_PATH = Rails.root.join("db/seeds/breed_images.yml")

    def self.call(...) = new(...).call

    def initialize(breed, limit: 3)
      @breed = breed
      @limit = limit
    end

    def call
      candidates.first(@limit)
    end

    # The catalog is small and already local, so there is nothing to paginate:
    # this exists so both adapters answer the same question the same way.
    def candidates
      entries.lazy.map { |entry| candidate_from(entry) }
    end

    private

    def entries
      return [] unless CATALOG_PATH.exist?

      catalog = YAML.safe_load_file(CATALOG_PATH) || {}
      Array(catalog[@breed.name]).select { |entry| entry["url"].present? && entry["license"].present? }
    end

    def candidate_from(entry)
      BreedImages::Candidate.new(
        source: SOURCE,
        source_id: entry["id"].presence || entry["url"],
        source_url: entry["url"],
        page_url: entry["page_url"],
        author: entry["author"],
        license: entry["license"],
        license_url: entry["license_url"],
        filename: File.basename(URI.parse(entry["url"]).path)
      )
    end
  end
end
