# frozen_string_literal: true

module Api
  module V2
    class BreedsController < Api::V2::BaseController
      include JsonapiPaginationDefaults

      before_action :cache_publicly

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
    end
  end
end
