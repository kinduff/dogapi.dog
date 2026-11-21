# frozen_string_literal: true

require "rails_helper"

RSpec.describe Umami::ClientWithUserAgent do
  it "sends events with a browser user agent" do
    request = stub_request(:post, "https://umami.example/api/send")
      .with(headers: {"User-Agent" => /\AMozilla\/5\.0 /})
      .to_return(status: 200, body: "{}")
    client = described_class.new(uri_base: "https://umami.example", access_token: "token")

    client.send_event({website: "site", url: "/api/v2/breeds", hostname: "dogapi.dog"})

    expect(request).to have_been_requested
  end

  describe "the initializer" do
    around do |example|
      client = Rails.application.config.umami_client
      website_id = Rails.application.config.umami_website_id
      example.run
    ensure
      Rails.application.config.umami_client = client
      Rails.application.config.umami_website_id = website_id
      Umami.reset if Umami.respond_to?(:reset)
    end

    def load_initializer
      stub_const("ENV", ENV.to_h.merge(
        "UMAMI_URI_BASE" => "https://umami.example",
        "UMAMI_USERNAME" => "someone",
        "UMAMI_PASSWORD" => "secret",
        "UMAMI_WEBSITE_ID" => "site"
      ))
      load Rails.root.join("config/initializers/umami.rb")
    end

    it "boots with tracking off when the login carries no token" do
      stub_request(:post, "https://umami.example/api/auth/login").to_return(status: 200, body: "{}")

      expect { load_initializer }.not_to raise_error
      expect(Rails.application.config.umami_client).to be_nil
    end

    it "boots with tracking off when umami cannot be reached" do
      stub_request(:post, "https://umami.example/api/auth/login").to_timeout

      expect { load_initializer }.not_to raise_error
      expect(Rails.application.config.umami_client).to be_nil
    end

    it "builds the client when the login works" do
      stub_request(:post, "https://umami.example/api/auth/login")
        .to_return(status: 200, body: {token: "abc"}.to_json)

      load_initializer

      expect(Rails.application.config.umami_client).to be_a(described_class)
    end
  end
end
