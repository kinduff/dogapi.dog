# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Disk service URLs are built from a route, so they need the host the request
  # came in on. Bucket services build their own URLs and ignore this.
  before_action :set_active_storage_url_options

  private

  def set_active_storage_url_options
    ActiveStorage::Current.url_options = {
      protocol: request.protocol,
      host: request.host,
      port: request.optional_port
    }
  end
end
