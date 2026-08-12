# frozen_string_literal: true

module Api
  module V2
    class BreedsController < Api::V2::BaseController
      include JsonapiPaginationDefaults

      before_action :cache_publicly

      def index
        jsonapi_paginate(breeds.order(:name)) do |paginated|
          render jsonapi: paginated
        end
      end

      def show
        @breed = breeds.find_by(id: params.fetch(:id))

        if @breed.nil?
          head :not_found
        else
          render jsonapi: @breed
        end
      end

      # GET /api/v2/breeds/:id/image
      # Redirects to one of the breed's images. `?size=` picks a variant and
      # `?random=true` picks any of the breed's images instead of the first.
      def image
        breed = Breed.find_by(id: params.fetch(:id))
        return head :not_found if breed.nil?

        redirect_to_image(random? ? breed.breed_images.with_files.sample : breed.primary_image)
      end

      # GET /api/v2/breeds/image
      # Redirects to a random image from any breed.
      def random_image
        redirect_to_image(BreedImage.with_files.offset(rand(BreedImage.count)).first)
      end

      private

      SIZES = BreedImage::VARIANTS.keys.map(&:to_s).freeze
      DEFAULT_SIZE = "medium"

      def redirect_to_image(breed_image)
        url = breed_image&.url_for(size)
        return head :not_found if url.blank?

        # The file lives on another host, and it is public.
        redirect_to url, allow_other_host: true, status: :found
      end

      # An unknown size falls back to the default rather than erroring, and
      # `full` asks for the untouched original.
      def size
        requested = params[:size].presence || DEFAULT_SIZE
        return if requested == "full"

        SIZES.include?(requested) ? requested : DEFAULT_SIZE
      end

      def random?
        ActiveModel::Type::Boolean.new.cast(params[:random])
      end

      # The serializer renders the group and every image URL, so both are
      # preloaded: otherwise a full page is a query per breed and per image.
      def breeds
        Breed.includes(:group, breed_images: {file_attachment: {blob: {variant_records: {image_attachment: :blob}}}})
      end
    end
  end
end
