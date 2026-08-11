# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API reference pages" do
  describe "GET /docs/api-v2" do
    before { get "/docs/api-v2" }

    it "renders" do
      expect(response).to have_http_status(:ok)
    end

    it "titles the page after the document" do
      expect(response.body).to include("<title>API V2 - Docs - Dog API by kinduff</title>")
    end

    it "states the base url" do
      expect(response.body).to include("https://dogapi.dog/api/v2")
    end

    it "links to the raw openapi document" do
      expect(response.body).to include('href="/api-docs/v2/swagger.json"')
    end

    it "lists every endpoint" do
      expect(response.body).to include("/breeds/{id}", "/groups/{id}", "/facts")
    end

    it "documents the query parameters" do
      expect(response.body).to include("page[size]", "Number of records per page (max 1000)")
    end

    it "documents both the success and the not found response" do
      expect(response.body).to include("api-status-2xx", "api-status-4xx")
    end

    it "shows a copy-pasteable request" do
      expect(response.body).to include("curl -s &quot;https://dogapi.dog/api/v2/breeds")
    end

    it "shows the response example" do
      expect(response.body).to include("Caucasian Shepherd Dog")
    end

    it "documents the models with anchors the tables link to" do
      expect(response.body).to include('id="model-range"', 'href="#model-range"')
    end

    it "loads no third party javascript" do
      expect(response.body).not_to include("cdnjs.cloudflare.com", "swagger-ui", "jsdelivr")
    end

    it "uses the wide variant of the site layout" do
      expect(response.body).to include('<main class="wide">')
    end

    it "keeps the site chrome" do
      expect(response.body).to include("Dog API", "Terms of Use")
    end
  end

  describe "GET /docs/api-v1" do
    before { get "/docs/api-v1" }

    it "renders the deprecated version too" do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("https://dogapi.dog/api/v1")
    end

    it "documents the aliases and the raw option" do
      expect(response.body).to include("number", "limit", "raw")
    end

    it "has no models section, since v1 declares none" do
      expect(response.body).not_to include('id="models"')
    end
  end
end
