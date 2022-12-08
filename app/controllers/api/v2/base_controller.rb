# frozen_string_literal: true

module Api
  module V2
    class BaseController < Api::BaseController
      include JSONAPI::Filtering

      after_action :track_action

      protected

      def track_action
        ahoy.track 'get_facts_v2', request.path_parameters
      end
    end
  end
end
