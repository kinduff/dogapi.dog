# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Homepage" do
  def rendered_text
    CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(response.body))
  end

  before { Rails.cache.clear }

  context "with data" do
    let!(:fact) { create(:fact, body: "Dogs have three eyelids.") }

    before do
      create_list(:breed, 3, group: create(:group))
      get "/"
    end

    it "renders" do
      expect(response).to have_http_status(:ok)
    end

    it "introduces the person behind it" do
      expect(rendered_text).to include("Hi, I'm kinduff")
    end

    it "shows a real fact from the database" do
      expect(response.body).to include(fact.body)
    end

    it "counts what the api actually holds instead of claiming a number" do
      expect(rendered_text).to include("3", "1", "breeds", "groups", "dog facts")
    end

    it "sends people to the docs and the breeds" do
      expect(response.body).to include('href="/docs"', 'href="/breeds"')
    end

    it "lets a visitor call the api without leaving the page" do
      expect(response.body).to include("data-api-try", 'data-base="/api/v2"', 'data-path="/facts"')
    end

    it "shows the img tag the image endpoint answers, highlighted" do
      expect(rendered_text).to include('<img src="https://dogapi.dog/api/v2/breeds/image">')
      expect(response.body).to include(%(<span class="nt">&lt;img</span>), %(<span class="na">src=</span>))
    end

    it "shows a copyable request, highlighted" do
      expect(rendered_text).to include('curl -s "https://dogapi.dog/api/v2/facts?limit=1"')
      expect(response.body).to include('<span class="code-line">')
    end

    it "shows how much the api is used" do
      expect(rendered_text).to include("about 60,000 requests on an average day")
    end

    it "answers the questions a teacher asks first" do
      expect(rendered_text).to include("Do I need an API key?", "300 requests per minute per IP")
    end

    it "gives the image dimensions so the layout does not jump" do
      expect(response.body).to match(/<img[^>]+width="1280"[^>]+height="720"/)
      expect(response.body).to include('loading="lazy"')
    end

    it "loads nothing from a javascript cdn" do
      expect(response.body).not_to include("unpkg.com", "cdnjs.cloudflare.com", "jsdelivr")
    end
  end

  describe "the grid at the top" do
    let(:group) { create(:group, name: "Working Group") }
    let!(:akita) { create(:breed, name: "Akita", group: group, life: {min: 10, max: 12}) }

    def pictured(name)
      breed = create(:breed, name: name, group: group)
      create(:breed_image, breed: breed, source_id: "File:#{name}.jpg")
      breed
    end

    it "shows a whole page of breeds rather than one" do
      create(:breed_image, breed: akita)
      3.times { |index| pictured("Breed #{index}") }

      get "/"

      expect(response.body.scan("home-hero-card").size).to eq(4)
    end

    it "leaves out the breeds with no picture imported" do
      create(:breed_image, breed: akita)
      create(:breed, name: "Pictureless", group: group)

      get "/"

      expect(response.body).to include('href="/breeds/akita"')
      expect(response.body).not_to include('href="/breeds/pictureless"')
    end

    it "links each picture to the breed it shows" do
      create(:breed_image, breed: akita)

      get "/"

      expect(response.body).to include('href="/breeds/akita"', 'alt="A Akita"')
    end

    # The grid is the whole thing now: no request line, no button, no script.
    it "asks for nothing beyond the pictures" do
      create(:breed_image, breed: akita)

      get "/"

      expect(response.body).not_to include("data-hero-shuffle", "home_hero", "home-hero-request")
    end

    it "is left out entirely when nothing has been imported yet" do
      get "/"

      expect(response.body).not_to include("home-hero-grid")
    end
  end

  context "with an empty database" do
    before { get "/" }

    it "still renders" do
      expect(response).to have_http_status(:ok)
      expect(rendered_text).to include("Try it")
    end
  end

  # The script hides this box when it renders an image response instead of
  # text, and it went missing here once.
  it "gives the try it panel the hook the script writes to" do
    get "/"

    expect(response.body).to include("data-api-body-box")
  end
end
