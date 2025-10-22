# frozen_string_literal: true

module Umami
  class ClientWithUserAgent < Client
    private

    def connection
      @connection ||= Faraday.new(url: uri_base) do |faraday|
        faraday.request :json
        faraday.response :raise_error
        faraday.adapter Faraday.default_adapter
        faraday.headers["Authorization"] = "Bearer #{@access_token}" if @access_token
        # Add User-Agent header for proper request tracking
        faraday.headers["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
        faraday.options.timeout = request_timeout
      end
    end
  end
end

if ENV['UMAMI_USERNAME'].present? && ENV['UMAMI_PASSWORD'].present?
  Umami.configure do |config|
    config.uri_base = ENV['UMAMI_URI_BASE']

    config.credentials = {
      username: ENV['UMAMI_USERNAME'],
      password: ENV['UMAMI_PASSWORD']
    }
  end

  Rails.application.config.umami_website_id = ENV['UMAMI_WEBSITE_ID']
  Rails.application.config.umami_client = Umami::ClientWithUserAgent.new
else
  Rails.application.config.umami_client = nil
  Rails.application.config.umami_website_id = nil
end
