# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Demo page" do
  before { get "/demo" }

  def rendered_text
    CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(response.body))
  end

  it "renders" do
    expect(response).to have_http_status(:ok)
  end

  it "offers a live panel for every endpoint" do
    expect(response.body.scan("data-api-try").size).to eq(6)
  end

  it "covers both versions" do
    expect(response.body).to include('data-base="/api/v1"', 'data-base="/api/v2"')
  end

  it "includes the single record endpoints" do
    expect(response.body).to include('data-path="/breeds/{id}"', 'data-path="/groups/{id}"')
  end

  it "prefills sensible starting values" do
    expect(response.body).to include('data-param="number"', 'data-param="page[size]"')
  end

  it "shows the equivalent javascript, highlighted" do
    expect(response.body).to include('<span class="kd">const</span>')
    expect(rendered_text).to include("await fetch")
  end

  it "uses the same code viewer as the docs" do
    expect(response.body).to include('<pre class="code-body code-body-tall">', '<span class="code-line">')
  end

  it "loads the shared script rather than a framework from a cdn" do
    expect(response.body).to match(%r{src="/assets/api_docs-\w+\.js"})
    expect(response.body).not_to include("unpkg.com", "cdnjs.cloudflare.com")
  end

  it "links back to the reference" do
    expect(response.body).to include(%(href="/docs"))
  end
end
