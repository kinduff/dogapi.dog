# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CORS" do
  let(:origin) { "https://example.com" }

  it "allows cross-origin GET requests to the API" do
    get "/api/v2/facts", headers: {"Origin" => origin}

    expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
  end

  it "allows a GET preflight" do
    process :options, "/api/v2/facts", headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => "GET"
    }

    expect(response).to have_http_status(:ok)
    expect(response.headers["Access-Control-Allow-Methods"]).to include("GET")
  end

  it "does not advertise write methods" do
    process :options, "/api/v2/facts", headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => "GET"
    }

    expect(response.headers["Access-Control-Allow-Methods"]).not_to include("POST")
  end

  it "rejects a POST preflight" do
    process :options, "/api/v2/facts", headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => "POST"
    }

    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end
end
