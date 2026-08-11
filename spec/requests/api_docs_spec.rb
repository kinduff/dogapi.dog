# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API reference pages" do
  # The code blocks are syntax highlighted, so their content is split across
  # spans. Assert on the text a reader actually sees.
  def rendered_text
    CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(response.body))
  end

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
      expect(rendered_text).to include('curl -s "https://dogapi.dog/api/v2/breeds')
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

    it "serves the interactive panel script from this origin" do
      expect(response.body).to match(%r{src="/assets/api_docs-\w+\.js"})
    end

    it "offers a try it form per operation" do
      expect(response.body.scan("data-api-try").size).to eq(5)
    end

    it "points the forms at this origin rather than the canonical host" do
      expect(response.body).to include('data-base="/api/v2"', 'data-path="/breeds/{id}"')
    end

    it "builds an input for every parameter" do
      expect(response.body).to include('data-param="page[size]"', 'data-in="query"')
      expect(response.body).to include('data-param="id"', 'data-in="path"')
    end

    it "prefills a path parameter with the documented example" do
      expect(response.body).to include('data-default="f9643a80-af1d-422a-9f15-18d466822053"')
    end

    it "lets the curl example be copied" do
      expect(response.body).to include('data-api-copy="get-breeds-curl"')
    end

    it "keeps wide content scrollable instead of stretching the page" do
      expect(response.body).to include('<div class="api-table-scroll">')
    end

    it "opens with a quick start before the reference" do
      expect(response.body.index("Quick start")).to be < response.body.index("Endpoints")
    end

    it "shows the first request in more than one language" do
      expect(rendered_text).to include("Terminal", "JavaScript", "await fetch")
    end

    it "explains how to read a response" do
      expect(response.body).to include("Reading a response", "relationships", "body.data[0].attributes.name")
    end

    it "numbers the lines of every code block" do
      expect(response.body).to include('<span class="code-line">')
    end

    it "highlights the examples" do
      expect(response.body).to include('<span class="nl">"data"</span>', '<span class="kd">const</span>')
    end

    it "bounds the height of long examples instead of dumping them inline" do
      expect(response.body).to include("code-body-tall")
    end

    it "folds the long field tables away behind a summary" do
      expect(response.body).to include("<summary>Every field, explained</summary>")
    end

    it "opens the success case and leaves the error case folded" do
      success = response.body.index('<details class="api-response" open>')
      folded = response.body.index('<details class="api-response" >')

      expect(success).to be_present
      expect(folded).to be_present
    end

    it "says where each parameter goes in plain words" do
      expect(response.body).to include("after the ?", "in the URL")
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
