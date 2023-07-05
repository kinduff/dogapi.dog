# frozen_string_literal: true

module Api
  module V2
    class FactsController < Api::V2::BaseController
      after_action :track_action

      def index
        @facts = Fact.order("RANDOM()").limit(get_limit)
        render jsonapi: @facts
      end

      private

      def get_limit
        limit = params[:limit]
        (limit.to_i.zero? || limit.to_i > 5) ? 1 : limit.to_i
      end

      protected

      def track_action
        ahoy.track "get_facts_v2", request.path_parameters
      end
    end
  end
end
