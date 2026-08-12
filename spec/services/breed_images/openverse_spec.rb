# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImages::Openverse do
  subject(:candidates) { described_class.call(breed, limit: 3) }

  let(:breed) { build(:breed, name: "Akita") }

  def result(id: "abc-123", title: "Akita in the snow", width: 1600, height: 1200, url: "https://live.staticflickr.com/akita.jpg")
    {
      "id" => id,
      "title" => title,
      "url" => url,
      "foreign_landing_url" => "https://flickr.com/photos/jane/1",
      "creator" => "Jane Photographer",
      "license" => "by-sa",
      "license_version" => "2.0",
      "width" => width,
      "height" => height
    }
  end

  def stub_openverse(*results)
    stub_request(:get, /api\.openverse\.org/)
      .to_return(status: 200, body: {"results" => results}.to_json, headers: {"Content-Type" => "application/json"})
  end

  it "maps a result into a candidate with its attribution" do
    stub_openverse(result)

    expect(candidates.first).to have_attributes(
      source: "openverse",
      source_id: "abc-123",
      source_url: "https://live.staticflickr.com/akita.jpg",
      page_url: "https://flickr.com/photos/jane/1",
      author: "Jane Photographer",
      license: "BY-SA 2.0",
      filename: "akita.jpg"
    )
  end

  it "asks only for licences that allow re-hosting and cropping" do
    stub_openverse

    candidates.to_a

    expect(a_request(:get, /api\.openverse\.org/)
      .with(query: hash_including("license_type" => "commercial,modification", "category" => "photograph")))
      .to have_been_made
  end

  it "refuses anything whose title says it is not a photograph of a dog" do
    stub_openverse(result(title: "Akita clip art"), result(id: "two", title: "Akita statue"))

    expect(candidates).to be_empty
  end

  it "refuses a picture below the quality floor" do
    stub_openverse(result(width: 200, height: 150))

    expect(candidates).to be_empty
  end

  it "keeps a result whose dimensions Openverse does not report" do
    stub_openverse(result(width: 0, height: 0))

    expect(candidates.size).to eq(1)
  end

  it "sends an identifiable user agent" do
    stub_openverse

    candidates.to_a

    expect(a_request(:get, /api\.openverse\.org/)
      .with(headers: {"User-Agent" => BreedImages.user_agent})).to have_been_made
  end

  it "raises a downloader error when Openverse is unavailable" do
    stub_request(:get, /api\.openverse\.org/).to_return(status: 503, body: "")

    expect { candidates.to_a }.to raise_error(BreedImages::Downloader::Error, /503/)
  end
end
