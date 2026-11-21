# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Markdown for agents" do
  let(:group) { create(:group, name: "Working Group") }
  let!(:akita) { create(:breed, name: "Akita", group: group, description: "A large Japanese breed.") }

  before { Rails.cache.clear }

  def get_markdown(path, accept: "text/markdown")
    get path, headers: {"Accept" => accept}
  end

  paths = {
    "the overview" => "/",
    "the terms" => "/terms",
    "the breeds" => "/breeds",
    "a breed" => "/breeds/akita",
    "the groups" => "/groups",
    "a group" => "/groups/working-group",
    "the docs index" => "/docs",
    "the teaching page" => "/teach",
    "the v1 docs" => "/docs/api-v1",
    "the v2 docs" => "/docs/api-v2"
  }

  paths.each do |name, path|
    it "serves #{name} as markdown when asked" do
      get_markdown path

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to eq("text/markdown; charset=utf-8")
      expect(response.body).not_to match(/<(html|body|main|div|script)\b/)
    end
  end

  it "keeps html the default" do
    get "/terms"

    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("<!DOCTYPE html>")
  end

  it "keeps html for a browser" do
    get_markdown "/terms", accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

    expect(response.media_type).to eq("text/html")
  end

  it "serves markdown when it is preferred among several types" do
    get_markdown "/terms", accept: "text/markdown, text/html;q=0.9, */*;q=0.8"

    expect(response.media_type).to eq("text/markdown")
  end

  it "keeps html when html is preferred over markdown" do
    get_markdown "/terms", accept: "text/html, text/markdown;q=0.5"

    expect(response.media_type).to eq("text/html")
  end

  it "tells caches the answer depends on the accept header, in both formats" do
    get "/breeds"
    expect(response.headers["Vary"]).to include("Accept")

    get_markdown "/breeds"
    expect(response.headers["Vary"]).to include("Accept")
  end

  it "opens with the page's title, description and address" do
    get_markdown "/breeds/akita"

    expect(response.body).to start_with("---\n")
    expect(response.body).to match(/^title: .*Akita/)
    expect(response.body).to match(/^description: .+/)
    expect(response.body).to include('url: "http://www.example.com/breeds/akita"')
  end

  it "carries the page's own content as markdown" do
    get_markdown "/breeds/akita"

    expect(response.body).to match(/^# .*Akita/)
    expect(response.body).to include("A large Japanese breed.")
  end

  it "writes a list of facts as one bullet each" do
    get_markdown "/breeds/akita"

    expect(response.body).to match(/^- \*\*Hypoallergenic\*\* ?: No$/)
  end

  it "writes a breed card as a single link" do
    get_markdown "/breeds"

    expect(response.body).to include("- [Akita, Working Group](http://www.example.com/breeds/akita)")
  end

  it "leaves the site header, navigation and footer out" do
    get_markdown "/terms"

    expect(response.body).not_to include("by kinduff", "Sitemap")
  end

  it "links with full addresses, so they resolve outside the site" do
    get_markdown "/groups/working-group"

    expect(response.body).to include("](http://www.example.com/breeds/akita)")
  end

  it "says roughly how many tokens the page costs" do
    get_markdown "/terms"

    expect(response.headers["X-Markdown-Tokens"].to_i).to be_positive
  end

  it "does not ask the reader to preload the stylesheet" do
    get_markdown "/terms"

    expect(response.headers["Link"]).to be_nil
  end

  it "answers a missing page in markdown too, still as a 404" do
    get_markdown "/breeds/no-such-dog"

    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("text/markdown")
  end

  it "leaves the api alone" do
    get_markdown "/api/v2/groups", accept: "text/markdown, application/json"

    expect(response.media_type).not_to eq("text/markdown")
  end

  it "leaves llms.txt as plain text" do
    get_markdown "/llms.txt"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/plain")
  end
end
