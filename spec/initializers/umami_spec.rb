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

    def load_initializer(env = {})
      stub_const("ENV", ENV.to_h.except("UMAMI_USERNAME", "UMAMI_PASSWORD").merge(
        "UMAMI_URI_BASE" => "https://umami.example",
        "UMAMI_WEBSITE_ID" => "site"
      ).merge(env).compact)
      load Rails.root.join("config/initializers/umami.rb")
    end

    # WebMock refuses any request that is not stubbed, so a login attempt here
    # would fail the example on its own.
    it "builds the client without logging in" do
      load_initializer

      expect(Rails.application.config.umami_client).to be_a(described_class)
      expect(a_request(:any, /umami\.example/)).not_to have_been_made
    end

    it "sends events without credentials or a token" do
      request = stub_request(:post, "https://umami.example/api/send").to_return(status: 200, body: "{}")
      load_initializer

      Rails.application.config.umami_client.send_event({website: "site", url: "/api/v2/breeds", hostname: "dogapi.dog"})

      expect(request.with { |sent| sent.headers.keys.none? { |name| name.casecmp?("Authorization") } }).to have_been_requested
    end

    it "leaves tracking off without a website to report to" do
      load_initializer("UMAMI_WEBSITE_ID" => nil)

      expect(Rails.application.config.umami_client).to be_nil
    end

    it "boots with tracking off when the client cannot be built" do
      allow(described_class).to receive(:new).and_raise(Umami::ConfigurationError, "no")

      expect { load_initializer }.not_to raise_error
      expect(Rails.application.config.umami_client).to be_nil
    end
  end
end
