# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    include UmamiTrackable
  end
end
