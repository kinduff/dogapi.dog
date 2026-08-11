# frozen_string_literal: true

require "rails_helper"

RSpec.describe UmamiEventJob do
  let(:client) { instance_double(Umami::Client) }
  let(:payload) { {"name" => "api_request"} }

  it "sends the payload to the client" do
    allow(Rails.application.config).to receive(:umami_client).and_return(client)
    allow(client).to receive(:send_event)

    described_class.perform_now(payload)

    expect(client).to have_received(:send_event).with(payload)
  end

  it "does nothing when no client is configured" do
    allow(Rails.application.config).to receive(:umami_client).and_return(nil)

    expect { described_class.perform_now(payload) }.not_to raise_error
  end

  it "swallows and logs client errors" do
    allow(Rails.application.config).to receive(:umami_client).and_return(client)
    allow(client).to receive(:send_event).and_raise(Faraday::ConnectionFailed, "down")
    allow(Rails.logger).to receive(:error)

    expect { described_class.perform_now(payload) }.not_to raise_error
    expect(Rails.logger).to have_received(:error).with(/Failed to track Umami event/)
  end
end
