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
end
