# frozen_string_literal: true

module Api
  module V1
    class FactsController < Api::V1::BaseController
      def index
        @facts = Fact.order("RANDOM()").limit(get_limit)
        if params[:raw] == "true"
          render plain: @facts.first.body
        else
          render json: {facts: @facts.map(&:body), success: true}
        end
      end

      private

      def get_limit
        limit = params[:number] || params[:limit]
        (limit.to_i.zero? || limit.to_i > 5) ? 1 : limit.to_i
      end
    end
  end
end
