# frozen_string_literal: true

module Api
  module V2
    class FactsController < Api::V2::BaseController
      def index
        @facts = Fact.random(get_limit)
        render jsonapi: @facts
      end

      private

      def get_limit
        params[:limit].to_i.clamp(1, 5)
      end
    end
  end
end
