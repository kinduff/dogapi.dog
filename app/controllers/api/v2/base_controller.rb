# frozen_string_literal: true

module Api
  module V2
    class BaseController < Api::BaseController
      include JSONAPI::Filtering
      include JSONAPI::Fetching

      # Breed and group data changes rarely, so responses can sit in shared
      # caches for a while. Rack::ETag still adds a validator built from the
      # rendered body, so clients get a 304 when nothing changed.
      CACHE_MAX_AGE = 5.minutes
      CACHE_STALE_WHILE_REVALIDATE = 1.hour

      private

      def cache_publicly
        expires_in CACHE_MAX_AGE,
          public: true,
          stale_while_revalidate: CACHE_STALE_WHILE_REVALIDATE
      end
    end
  end
end
