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

      private

      # The serializer renders the group and every image URL, so both are
      # preloaded: otherwise a full page is a query per breed and per image.
      def breeds
        Breed.includes(:group, breed_images: {file_attachment: {blob: {variant_records: {image_attachment: :blob}}}})
      end
    end
  end
end
