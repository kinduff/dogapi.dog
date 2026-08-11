# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pages" do
  paths = {
    "the overview" => "/",
    "the terms" => "/terms",
    "the demo" => "/demo",
    "the docs index" => "/docs",
    "the v1 docs" => "/docs/api-v1",
    "the v2 docs" => "/docs/api-v2"
  }

  paths.each do |name, path|
    it "renders #{name}" do
      get path

      expect(response).to have_http_status(:ok)
    end
  end

  it "renders the overview without any facts in the database" do
    get "/"

    expect(response).to have_http_status(:ok)
  end

  it "shows a fact on the overview" do
    fact = create(:fact, body: "Dogs have three eyelids.")

    get "/"

    expect(response.body).to include(fact.body)
  end

  it "sends a content security policy" do
    get "/demo"

    expect(response.headers["Content-Security-Policy"]).to include("default-src 'self'")
  end

  it "needs no inline script on the demo page" do
    get "/demo"

    expect(response.body).not_to match(/<script(?![^>]*src=)/)
  end

  it "loads no third party javascript at all" do
    get "/demo"

    expect(response.headers["Content-Security-Policy"]).to include("script-src 'self' https://good.lasagna.pizza")
  end
end
