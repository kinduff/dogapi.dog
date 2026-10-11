# frozen_string_literal: true

module Umami
  class ClientWithUserAgent < Client
    private

    # send_event defaults to "umami-ruby/VERSION"; send a browser string instead
    # so events are tracked like a real visit.
    def default_user_agent
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
    end
  end
end

if ENV["UMAMI_USERNAME"].present? && ENV["UMAMI_PASSWORD"].present?
  Umami.configure do |config|
    config.uri_base = ENV["UMAMI_URI_BASE"]

    config.credentials = {
      username: ENV["UMAMI_USERNAME"],
      password: ENV["UMAMI_PASSWORD"]
    }
  end

  Rails.application.config.umami_website_id = ENV["UMAMI_WEBSITE_ID"]
  Rails.application.config.umami_client = Umami::ClientWithUserAgent.new
else
  Rails.application.config.umami_client = nil
  Rails.application.config.umami_website_id = nil
end
