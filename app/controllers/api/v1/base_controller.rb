# frozen_string_literal: true

module Api
  module V1
    class BaseController < Api::BaseController
      after_action :track_action

      protected

      def track_action
        ahoy.track "get_facts_v1", request.path_parameters
      end
    end
  end
end
