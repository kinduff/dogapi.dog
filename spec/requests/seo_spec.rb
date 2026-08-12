# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SEO metadata" do
  let(:group) { create(:group, name: "Working Group") }
  let!(:akita) do
    create(:breed, name: "Akita", group: group, description: "A large Japanese breed.",
      life: {"min" => 10, "max" => 14}, male_weight: {"min" => 32, "max" => 39})
  end

  before { Rails.cache.clear }

  def meta(name)
    response.body[/<meta name="#{name}" content="([^"]*)"/, 1]
  end

  def property(name)
    response.body[/<meta property="#{name}" content="([^"]*)"/, 1]
  end

  def canonical
    response.body[/<link rel="canonical" href="([^"]*)"/, 1]
  end

  def json_ld
    JSON.parse(response.body[%r{<script type="application/ld\+json"[^>]*>(.*?)</script>}m, 1])
  end

  describe "a breed page" do
    it "describes this breed rather than the API" do
      get "/breeds/akita"

      expect(meta("description")).to include("Akita", "Working", "10–14 years", "32–39 kg")
    end

    it "keeps the description short enough to survive a search result" do
      create(:breed, name: "Wordy", group: group, description: "Lorem ipsum. " * 60)

      get "/breeds/wordy"

      expect(meta("description").length).to be <= ApplicationHelper::MAX_DESCRIPTION
    end

    it "points the canonical at the slug, not at the id" do
      get "/breeds/#{akita.id}"

      expect(canonical).to eq("http://www.example.com/breeds/akita")
    end

    it "shares the breed's own picture" do
      image = create(:breed_image, breed: akita)

      get "/breeds/akita"

      expect(property("og:image")).to include(image.file.filename.to_s.sub(".jpg", ".webp"))
    end

    it "falls back to the site image when the breed has none" do
      get "/breeds/akita"

      expect(property("og:image")).to include("social")
    end

    it "shares its own url" do
      get "/breeds/akita"

      expect(property("og:url")).to eq("http://www.example.com/breeds/akita")
    end

    it "carries structured data naming the breed and its group" do
      get "/breeds/akita"

      data = json_ld
      expect(data["name"]).to eq("Akita")
      expect(data["url"]).to eq("http://www.example.com/breeds/akita")
      expect(data.dig("isPartOf", "name")).to eq("Working Group")
    end

    it "credits each image in the structured data" do
      create(:breed_image, breed: akita, author: "Jane", license_url: "https://example.com/licence")

      get "/breeds/akita"

      image = json_ld["image"].first
      expect(image["@type"]).to eq("ImageObject")
      expect(image["creditText"]).to eq("Jane")
      expect(image["license"]).to eq("https://example.com/licence")
    end

    it "cannot be broken out of by a description containing a script tag" do
      create(:breed, name: "Sneaky", group: group, description: "</script><script>alert(1)</script>")

      get "/breeds/sneaky"

      expect(response.body).not_to include("<script>alert(1)")
      expect(json_ld["description"]).to include("script")
    end

    it "is indexable" do
      get "/breeds/akita"

      expect(meta("robots")).to be_nil
    end
  end

  describe "the breed list" do
    it "canonicalises the first page to the bare path" do
      get "/breeds"

      expect(canonical).to eq("http://www.example.com/breeds")
    end

    it "lets a later page be its own canonical" do
      create_list(:breed, 3, group: group)

      get "/breeds", params: {page: {number: 2, size: 1}}

      expect(canonical).to eq("http://www.example.com/breeds?page%5Bnumber%5D=2")
    end

    it "keeps search results out of the index but follows their links" do
      get "/breeds", params: {q: "aki"}

      expect(meta("robots")).to eq("noindex, follow")
      expect(canonical).to eq("http://www.example.com/breeds")
    end

    it "says how many breeds there are" do
      get "/breeds"

      expect(meta("description")).to include("dog breeds")
    end
  end

  describe "a group page" do
    it "describes the group" do
      get "/groups/working-group"

      expect(meta("description")).to include("Working Group")
    end

    it "lists its breeds as structured data" do
      get "/groups/working-group"

      data = json_ld
      expect(data["@type"]).to eq("CollectionPage")
      expect(data["hasPart"].map { |part| part["name"] }).to include("Akita")
    end
  end

  describe "the homepage" do
    it "keeps the site wide description" do
      get "/"

      expect(meta("description")).to eq(ApplicationHelper::DEFAULT_DESCRIPTION)
    end

    it "canonicalises to itself" do
      get "/"

      expect(canonical).to eq("http://www.example.com/")
    end
  end

  describe "GET /sitemap.xml" do
    it "is xml" do
      get "/sitemap.xml"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/xml")
    end

    it "lists the static pages, the breeds and the groups" do
      get "/sitemap.xml"

      expect(response.body).to include(
        "<loc>http://www.example.com/</loc>",
        "<loc>http://www.example.com/breeds</loc>",
        "<loc>http://www.example.com/breeds/akita</loc>",
        "<loc>http://www.example.com/groups/working-group</loc>",
        "<loc>http://www.example.com/docs/api-v2</loc>"
      )
    end

    it "carries a last modified date for records" do
      get "/sitemap.xml"

      expect(response.body).to include("<lastmod>#{akita.updated_at.iso8601}</lastmod>")
    end
  end

  describe "GET /llms.txt" do
    it "is plain text" do
      get "/llms.txt"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/plain")
    end

    it "opens with the title and the one line summary the format asks for" do
      get "/llms.txt"

      expect(response.body).to start_with("# Dog API\n\n> ")
    end

    it "counts what the API holds right now" do
      get "/llms.txt"

      expect(response.body).to include("1 breeds", "1 groups")
    end

    it "quotes the rate limit actually in force" do
      get "/llms.txt"

      expect(response.body).to include("#{Rack::Attack::REQUESTS_PER_MINUTE} a minute per IP")
    end

    it "links every documented endpoint" do
      get "/llms.txt"

      OpenapiDocument.load("v2").operations.each do |operation|
        expect(response.body).to include("[GET /api/v2#{operation.path}]")
      end
    end

    it "links the pages on the host the request came in on" do
      get "/llms.txt"

      expect(response.body).to include(
        "(http://www.example.com/breeds)",
        "(http://www.example.com/groups)",
        "(http://www.example.com/sitemap.xml)",
        "(http://www.example.com/api-docs/v2/swagger.json)"
      )
    end

    it "points at anchors that exist on the reference it links to" do
      get "/llms.txt"
      anchors = response.body.scan(%r{/docs/api-v2#([\w-]+)\)}).flatten

      get "/docs/api-v2"

      expect(anchors).not_to be_empty
      anchors.each { |anchor| expect(response.body).to include(%(id="#{anchor}")) }
    end
  end
end
