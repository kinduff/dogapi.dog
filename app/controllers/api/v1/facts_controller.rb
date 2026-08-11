# frozen_string_literal: true

module Api
  module V1
    class FactsController < Api::V1::BaseController
      def index
        @facts = Fact.order("RANDOM()").limit(get_limit)
        if params[:raw] == "true"
          fact = @facts.first
          fact.nil? ? head(:not_found) : render(plain: fact.body)
        else
          render json: {facts: @facts.map(&:body), success: true}
        end
      end

      private

      def get_limit
        limit = params[:number] || params[:limit]
        limit.to_i.clamp(1, 5)
      end
    end
  end
end
