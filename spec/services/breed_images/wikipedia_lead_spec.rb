# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImages::WikipediaLead do
  # One article, one lead picture: asking for more only makes it try the
  # breed's other names, which is what the fallback example below is for.
  subject(:candidates) { described_class.call(breed, limit: 1) }

  let(:breed) { build(:breed, name: "Akita", other_names: ["Akita Inu"]) }

  def stub_article(pageimage, title: "Akita")
    page = pageimage.nil? ? {"title" => title, "missing" => ""} : {"title" => title, "pageimage" => pageimage}

    # Matched by query rather than by pattern: an unanchored "titles=Akita"
    # would also answer for "Akita Inu", and the two mean different things here.
    stub_request(:get, "https://en.wikipedia.org/w/api.php")
      .with(query: hash_including("titles" => title))
      .to_return(
        status: 200,
        body: {"query" => {"pages" => {"1" => page}}}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  def stub_commons(title:, width: 1200, height: 900, license: "CC BY-SA 4.0")
    stub_request(:get, /commons\.wikimedia\.org/).to_return(
      status: 200,
      body: {"query" => {"pages" => {"1" => {
        "title" => "File:#{title}",
        "imageinfo" => [{
          "url" => "https://upload.wikimedia.org/#{title}",
          "descriptionurl" => "https://commons.wikimedia.org/wiki/File:#{title}",
          "mime" => "image/jpeg",
          "width" => width,
          "height" => height,
          "size" => 500_000,
          "extmetadata" => {
            "Artist" => {"value" => "<a href='#'>Jane</a>"},
            "LicenseShortName" => {"value" => license},
            "LicenseUrl" => {"value" => "https://creativecommons.org/licenses/by-sa/4.0/"}
          }
        }]
      }}}}.to_json,
      headers: {"Content-Type" => "application/json"}
    )
  end

  def stub_article_search(*titles)
    stub_request(:get, "https://en.wikipedia.org/w/api.php")
      .with(query: hash_including("list" => "search"))
      .to_return(
        status: 200,
        body: {"query" => {"search" => titles.map { |title| {"title" => title} }}}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  # The breed's other names are tried whenever the first title yields nothing
  # usable, and then a search, so every example needs an answer for both. A
  # later stub wins.
  before do
    stub_article(nil, title: "Akita Inu")
    stub_article_search
  end

  it "takes the picture the article leads with, credited from Commons" do
    stub_article("Akita_inu.jpg")
    stub_commons(title: "Akita_inu.jpg")

    expect(candidates.first).to have_attributes(
      source: "wikimedia_commons",
      source_id: "File:Akita_inu.jpg",
      source_url: "https://upload.wikimedia.org/Akita_inu.jpg",
      page_url: "https://commons.wikimedia.org/wiki/File:Akita_inu.jpg",
      author: "Jane",
      license: "CC BY-SA 4.0"
    )
  end

  it "shares Commons' source id, so an image is never stored twice" do
    stub_article("Akita_inu.jpg")
    stub_commons(title: "Akita_inu.jpg")

    expect(candidates.first.source).to eq(BreedImages::WikimediaCommons::SOURCE)
  end

  it "falls back to an alternative name when the breed has no article" do
    stub_article(nil, title: "Akita")
    stub_article("Akita_inu.jpg", title: "Akita Inu")
    stub_commons(title: "Akita_inu.jpg")

    expect(candidates.size).to eq(1)
  end

  it "asks Wikipedia which article is about the dog when the plain title is not" do
    stub_article(nil, title: "Akita")
    stub_article_search("Akita (dog breed)", "List of dog breeds")
    stub_article("Akita_inu.jpg", title: "Akita (dog breed)")
    stub_commons(title: "Akita_inu.jpg")

    expect(candidates.size).to eq(1)
  end

  it "ignores the articles a search returns that are not about this breed" do
    stub_article(nil, title: "Akita")
    stub_article_search("Dog", "List of dog breeds")

    expect(candidates).to be_empty
  end

  it "yields nothing when no article names a picture" do
    stub_article(nil, title: "Akita")
    stub_article(nil, title: "Akita Inu")

    expect(candidates).to be_empty
  end

  it "applies the same quality floor as the other Commons sources" do
    stub_article("Akita_inu.jpg")
    stub_commons(title: "Akita_inu.jpg", width: 200, height: 150)

    expect(candidates).to be_empty
  end

  it "refuses a picture whose licence forbids re-use" do
    stub_article("Akita_inu.jpg")
    stub_commons(title: "Akita_inu.jpg", license: "Fair use")

    expect(candidates).to be_empty
  end

  it "sends an identifiable user agent" do
    stub_article("Akita_inu.jpg")
    stub_commons(title: "Akita_inu.jpg")

    candidates

    expect(a_request(:get, /en\.wikipedia\.org/)
      .with(headers: {"User-Agent" => BreedImages.user_agent})).to have_been_made
  end

  it "raises a downloader error when Wikipedia is unavailable" do
    stub_request(:get, /en\.wikipedia\.org/).to_return(status: 503, body: "")

    expect { candidates.to_a }.to raise_error(BreedImages::Downloader::Error, /503/)
  end
end
