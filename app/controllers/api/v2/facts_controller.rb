# frozen_string_literal: true

module Api
  module V2
    class FactsController < Api::V2::BaseController
      def index
        @facts = Fact.order("RANDOM()").limit(get_limit)
        render jsonapi: @facts
      end

      private

      def get_limit
        limit = params[:limit]
        (limit.to_i.zero? || limit.to_i > 5) ? 1 : limit.to_i
      end
    end
  end
end
