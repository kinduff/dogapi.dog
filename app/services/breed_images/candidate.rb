# frozen_string_literal: true

module BreedImages
  # One importable picture as an adapter describes it, before anything is
  # downloaded. `source_id` is the source's own stable id and is what makes an
  # import idempotent.
  Candidate = Struct.new(
    :source,
    :source_id,
    :source_url,
    :page_url,
    :author,
    :license,
    :license_url,
    :filename,
    keyword_init: true
  ) do
    def to_attributes
      {
        source: source,
        source_id: source_id,
        source_url: source_url,
        page_url: page_url,
        author: author,
        license: license,
        license_url: license_url
      }
    end
  end
end
