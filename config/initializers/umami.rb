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

if ENV["UMAMI_URI_BASE"].present? && ENV["UMAMI_WEBSITE_ID"].present?
  Rails.application.config.umami_website_id = ENV["UMAMI_WEBSITE_ID"]
  # Analytics must cost the events and nothing else, so a client that cannot be
  # built leaves tracking off rather than taking the site with it.
  Rails.application.config.umami_client =
    begin
      # The app only ever sends events, and Umami takes those from anyone: it
      # is the endpoint the browser script posts to. The gem still wants a
      # token before it will build a client, and logs in over the network for
      # one if it has none, so it is handed a stand-in. Sending an event never
      # uses it.
      Umami::ClientWithUserAgent.new(uri_base: ENV["UMAMI_URI_BASE"], access_token: "events-need-no-login")
    rescue => error
      Rails.logger.error("Umami tracking is off, the client could not be built: #{error.class}: #{error.message}")
      Honeybadger.notify(error) if defined?(Honeybadger)
      nil
    end
else
  Rails.application.config.umami_client = nil
  Rails.application.config.umami_website_id = nil
end
