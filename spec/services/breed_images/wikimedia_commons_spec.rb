# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImages::WikimediaCommons do
  subject(:candidates) { described_class.call(breed, limit: 2) }

  let(:breed) { build(:breed, name: "Akita") }

  def page(title:, mime: "image/jpeg", license: "CC BY-SA 4.0", artist: "<a href='#'>Jane</a>")
    {
      "title" => title,
      "imageinfo" => [{
        "url" => "https://upload.wikimedia.org/#{title.delete_prefix("File:")}",
        "descriptionurl" => "https://commons.wikimedia.org/wiki/#{title}",
        "mime" => mime,
        "extmetadata" => {
          "Artist" => {"value" => artist},
          "LicenseShortName" => {"value" => license},
          "LicenseUrl" => {"value" => "https://creativecommons.org/licenses/by-sa/4.0/"}
        }
      }]
    }
  end

  def stub_commons(pages)
    stub_request(:get, /commons\.wikimedia\.org/)
      .to_return(
        status: 200,
        body: {"query" => {"pages" => pages.each_with_index.to_h { |p, i| [i.to_s, p] }}}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  it "maps a result into a candidate with its attribution" do
    stub_commons([page(title: "File:Akita inu.jpg")])

    expect(candidates.size).to eq(1)
    expect(candidates.first).to have_attributes(
      source: "wikimedia_commons",
      source_id: "File:Akita inu.jpg",
      source_url: "https://upload.wikimedia.org/Akita inu.jpg",
      page_url: "https://commons.wikimedia.org/wiki/File:Akita inu.jpg",
      author: "Jane",
      license: "CC BY-SA 4.0",
      filename: "Akita_inu.jpg"
    )
  end

  it "sends an identifiable user agent" do
    stub_commons([])

    candidates

    expect(a_request(:get, /commons\.wikimedia\.org/)
      .with(headers: {"User-Agent" => BreedImages.user_agent})).to have_been_made
  end

  it "searches for the breed name in the file namespace" do
    stub_commons([])

    candidates

    expect(a_request(:get, /commons\.wikimedia\.org/)
      .with(query: hash_including("gsrsearch" => "filetype:bitmap Akita dog", "gsrnamespace" => "6")))
      .to have_been_made
  end

  it "drops non image results" do
    stub_commons([page(title: "File:Akita.pdf", mime: "application/pdf")])

    expect(candidates).to be_empty
  end

  it "drops results without a usable licence" do
    stub_commons([
      page(title: "File:A.jpg", license: "Fair use"),
      page(title: "File:B.jpg", license: "")
    ])

    expect(candidates).to be_empty
  end

  it "stops at the requested limit" do
    stub_commons([page(title: "File:A.jpg"), page(title: "File:B.jpg"), page(title: "File:C.jpg")])

    expect(candidates.map(&:source_id)).to eq(["File:A.jpg", "File:B.jpg"])
  end

  it "returns nothing when the search has no results" do
    stub_request(:get, /commons\.wikimedia\.org/)
      .to_return(status: 200, body: {"batchcomplete" => ""}.to_json, headers: {"Content-Type" => "application/json"})

    expect(candidates).to be_empty
  end

  it "raises a downloader error on an API failure" do
    stub_request(:get, /commons\.wikimedia\.org/).to_return(status: 503, body: "")

    expect { candidates }.to raise_error(BreedImages::Downloader::Error, /503/)
  end
end
