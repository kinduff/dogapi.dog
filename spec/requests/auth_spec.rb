# frozen_string_literal: true

require "rails_helper"

RSpec.describe "auth.md" do
  before { get "/auth.md" }

  it "is served as markdown" do
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
  end

  it "opens with a heading that names the file" do
    expect(response.body).to start_with("# Dog API auth.md\n")
  end

  it "tells an agent there is nothing to register for" do
    expect(response.body).to include("needs no authentication", "no registration endpoint", "Anonymous access")
  end

  it "does not claim an oauth server that does not exist" do
    expect(response.body).to include("no OAuth authorization server")

    get "/.well-known/oauth-protected-resource"

    expect(response).to have_http_status(:not_found)
  end

  it "states the rate limit actually in force" do
    expect(response.body).to include("#{Rack::Attack::REQUESTS_PER_MINUTE} a minute")
  end

  it "points at documents that exist" do
    paths = response.body.scan(%r{\]\(http://www\.example\.com([^)]*)\)}).flatten

    expect(paths).not_to be_empty
    paths.each do |path|
      get path

      expect(response).to have_http_status(:ok), "#{path} answered #{response.status}"
    end
  end
end
