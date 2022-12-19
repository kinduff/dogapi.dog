# frozen_string_literal: true

module Api
  module V2
    class BreedsController < Api::V2::BaseController
      include JSONAPI::Pagination

      def index
        jsonapi_paginate(Breed.all) do |paginated|
          render jsonapi: paginated
        end
      end

      def show
        render jsonapi: Breed.find_by(id: params.fetch(:id))
      end

      private

      def jsonapi_page_size(pagination_params)
        per_page = pagination_params[:size].to_f.to_i
        per_page = 10 if per_page > 10 || per_page < 1
        per_page
      end
    end
  end
end
