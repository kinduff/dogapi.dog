# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Umami tracking" do
  before { create(:fact) }

  context "when Umami is not configured" do
    it "does not enqueue anything" do
      expect { get "/api/v2/facts" }.not_to have_enqueued_job(UmamiEventJob)
    end
  end

  context "when Umami is configured" do
    before do
      allow(Rails.application.config).to receive_messages(
        umami_client: instance_double(Umami::Client),
        umami_website_id: "website-id"
      )
    end

    it "enqueues a job instead of tracking inline" do
      expect { get "/api/v2/facts" }.to have_enqueued_job(UmamiEventJob)
    end

    it "passes the event payload to the job" do
      get "/api/v2/facts"

      payload = ActiveJob::Base.queue_adapter.enqueued_jobs.last["arguments"].first

      expect(payload).to include(
        "website" => "website-id",
        "name" => "api_request",
        "url" => "http://www.example.com/api/v2/facts"
      )
    end

    it "still serves the request when building the payload fails" do
      allow(Rails.application.config).to receive(:umami_website_id).and_raise("boom")

      get "/api/v2/facts"

      expect(response).to have_http_status(:ok)
    end
  end
end
