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
  # Building the client logs in to Umami, over the network, while the app is
  # booting. Analytics being down or refusing the login must cost the events
  # and nothing else, so a failure here leaves tracking off rather than taking
  # the site with it.
  Rails.application.config.umami_client =
    begin
      Umami::ClientWithUserAgent.new
    rescue => error
      Rails.logger.error("Umami tracking is off, the client could not be built: #{error.class}: #{error.message}")
      Honeybadger.notify(error) if defined?(Honeybadger)
      nil
    end
else
  Rails.application.config.umami_client = nil
  Rails.application.config.umami_website_id = nil
end
