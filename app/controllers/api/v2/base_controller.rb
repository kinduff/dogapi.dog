# frozen_string_literal: true

module Api
  module V2
    class BaseController < Api::BaseController
      include JSONAPI::Filtering
      include JSONAPI::Fetching
    end
  end
end
