# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API catalog" do
  before { host! "dogapi.dog" }

  # Rails only parses a body whose media type it knows, and this one it does not.
  def linkset
    JSON.parse(response.body).fetch("linkset")
  end

  def entry(version)
    linkset.find { |api| api["anchor"].end_with?("/api/#{version}") }
  end

  it "answers at the well known address as a linkset" do
    get "/.well-known/api-catalog"

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Type"])
      .to start_with('application/linkset+json; profile="https://www.rfc-editor.org/info/rfc9727"')
  end

  it "lists both versions of the api, newest first" do
    get "/.well-known/api-catalog"

    anchors = linkset.pluck("anchor")

    expect(anchors).to eq(%w[http://dogapi.dog/api/v2 http://dogapi.dog/api/v1])
  end

  it "points each api at its openapi document, its docs and the health check" do
    get "/.well-known/api-catalog"

    expect(entry("v2")).to include(
      "service-desc" => [{"href" => "http://dogapi.dog/api-docs/v2/swagger.json", "type" => "application/json"}],
      "service-doc" => [{"href" => "http://dogapi.dog/docs/api-v2", "type" => "text/html"}],
      "status" => [{"href" => "http://dogapi.dog/up"}]
    )
  end

  it "points at documents that exist" do
    get "/.well-known/api-catalog"
    links = entry("v1").values_at("service-desc", "service-doc", "status").flatten.pluck("href")

    links.each do |link|
      get URI(link).path

      expect(response).to have_http_status(:ok), "#{link} answered #{response.status}"
    end
  end

  it "says where the catalog is when only asked for the headers" do
    head "/.well-known/api-catalog"

    expect(response).to have_http_status(:ok)
    expect(response.headers["Link"]).to eq('</.well-known/api-catalog>; rel="api-catalog"')
  end

  it "answers a request for markdown with the catalog all the same" do
    get "/.well-known/api-catalog", headers: {"Accept" => "text/markdown"}

    expect(response.headers["Content-Type"]).to start_with("application/linkset+json")
  end
end
