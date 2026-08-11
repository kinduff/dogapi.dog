# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    include UmamiTrackable

    private

    # Random responses must never be stored by a proxy or the browser.
    def do_not_cache
      response.cache_control.replace(no_store: true)
    end
  end
end
