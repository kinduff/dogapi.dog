# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MCP server card" do
  before { host! "dogapi.dog" }

  def card
    JSON.parse(response.body)
  end

  def handshake
    post "/mcp", params: {jsonrpc: "2.0", id: 1, method: "initialize", params: {}}.to_json,
      headers: {"Content-Type" => "application/json"}

    JSON.parse(response.body).fetch("result")
  end

  describe "at the address the specification reserves" do
    before { get "/mcp/server-card" }

    it "is served as a server card" do
      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to start_with("application/mcp-server-card+json")
    end

    it "carries every field the schema requires, in the form it requires" do
      expect(card).to include(
        "$schema" => "https://static.modelcontextprotocol.io/schemas/v1/server-card.schema.json",
        "version" => McpController::SERVER_VERSION
      )
      expect(card["name"]).to match(%r{\A[a-zA-Z0-9.-]+/[a-zA-Z0-9._-]+\z})
      expect(card["description"].length).to be_between(1, 100)
      expect(card["title"].length).to be_between(1, 100)
    end

    it "says where to connect and which protocol versions to try" do
      expect(card["remotes"]).to eq([{
        "type" => "streamable-http",
        "url" => "http://dogapi.dog/mcp",
        "supportedProtocolVersions" => McpController::PROTOCOL_VERSIONS
      }])
    end

    it "keeps to the fields the schema defines" do
      expect(card.keys - %w[$schema name version description title websiteUrl repository icons remotes _meta]).to be_empty
    end

    it "lists no tools, which belong to tools/list" do
      expect(card).not_to include("tools")
    end

    it "may be cached for an hour and carries a validator" do
      expect(response.headers["Cache-Control"]).to eq("max-age=3600, public")
      expect(response.headers["ETag"]).to be_present
    end

    it "does not disagree with the handshake" do
      title = card["title"]
      version = card["version"]

      expect(handshake["serverInfo"]).to include("title" => title, "version" => version)
    end
  end

  describe "at the well known address" do
    before { get "/.well-known/mcp/server-card.json" }

    it "is served as json" do
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
    end

    it "is the same card with the earlier drafts' fields added" do
      well_known = card
      get "/mcp/server-card"

      expect(well_known).to include(card)
      expect(well_known.keys - card.keys).to contain_exactly("serverInfo", "transport", "capabilities")
    end

    it "names the server, its endpoint and what it can do, as the handshake does" do
      well_known = card
      live = handshake

      expect(well_known["serverInfo"]).to eq(live["serverInfo"])
      expect(well_known["capabilities"]).to eq(live["capabilities"])
      expect(well_known["transport"]).to eq("type" => "streamable-http", "endpoint" => "http://dogapi.dog/mcp")
    end
  end

  %w[/mcp/server-card /.well-known/mcp/server-card.json].each do |path|
    it "lets a browser on another origin read #{path} and its etag" do
      get path, headers: {"Origin" => "https://client.example"}

      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Expose-Headers"]).to include("ETag")
    end
  end

  it "leaves the server itself answering at /mcp" do
    expect(handshake["serverInfo"]["name"]).to eq("dogapi.dog")
  end
end
