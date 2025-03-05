# frozen_string_literal: true

module Api
  module V2
    class BreedsController < Api::V2::BaseController
      include JSONAPI::Pagination

      after_action :track_action

      def index
        jsonapi_paginate(Breed.order(:name)) do |paginated|
          render jsonapi: paginated
        end
      end

      def show
        @breed = Breed.find_by(id: params.fetch(:id))

        if @breed.nil?
          head :not_found
        else
          render jsonapi: @breed
        end
      end

      private

      def jsonapi_page_size(pagination_params)
        per_page = pagination_params[:size].to_f.to_i
        per_page = 10 if per_page > 10 || per_page < 1
        per_page
      end

      def jsonapi_meta(resources)
        pagination = jsonapi_pagination_meta(resources)

        { pagination: pagination } if pagination.present?
      end

      protected

      def track_action
        ahoy.track "get_breeds_v2", request.path_parameters
      end
    end
  end
end
