# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImages::WikimediaCommons do
  subject(:candidates) { described_class.call(breed, limit: 2) }

  let(:breed) { build(:breed, name: "Akita") }

  def page(title:, mime: "image/jpeg", license: "CC BY-SA 4.0", artist: "<a href='#'>Jane</a>", width: 1200, height: 900, size: 500_000)
    {
      "title" => title,
      "imageinfo" => [{
        "url" => "https://upload.wikimedia.org/#{title.delete_prefix("File:")}",
        "descriptionurl" => "https://commons.wikimedia.org/wiki/#{title}",
        "mime" => mime,
        "width" => width,
        "height" => height,
        "size" => size,
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

  it "drops images that are too small to be photographs" do
    stub_commons([page(title: "File:A.jpg", width: 120, height: 90)])

    expect(candidates).to be_empty
  end

  it "drops images below the pixel floor even when both sides pass" do
    stub_commons([page(title: "File:A.jpg", width: 420, height: 420)])

    expect(candidates).to be_empty
  end

  it "drops panoramas that would not survive a square crop" do
    stub_commons([page(title: "File:A.jpg", width: 4000, height: 600)])

    expect(candidates).to be_empty
  end

  it "drops results whose title says they are not photographs" do
    stub_commons([
      page(title: "File:Akita logo.jpg"),
      page(title: "File:Map of Akita prefecture.jpg"),
      page(title: "File:Akita coat of arms.jpg")
    ])

    expect(candidates).to be_empty
  end

  it "keeps a title that merely contains a rejected word inside another" do
    stub_commons([page(title: "File:Akita mapache.jpg")])

    expect(candidates.size).to eq(1)
  end

  it "drops files too big to store, without downloading them" do
    stub_commons([page(title: "File:Huge.png", size: BreedImage::MAX_BYTE_SIZE + 1)])

    expect(candidates).to be_empty
  end

  it "walks to the next page when the first one is all rejects" do
    stub_request(:get, /commons\.wikimedia\.org/)
      .to_return(
        status: 200,
        body: {"query" => {"pages" => {"0" => page(title: "File:Akita logo.jpg")}},
               "continue" => {"gsroffset" => 20, "continue" => "gsroffset||"}}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
      .then.to_return(
        status: 200,
        body: {"query" => {"pages" => {"0" => page(title: "File:Akita real.jpg")}}}.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    expect(candidates.map(&:source_id)).to eq(["File:Akita real.jpg"])
    expect(a_request(:get, /commons\.wikimedia\.org/).with(query: hash_including("gsroffset" => "20")))
      .to have_been_made
  end

  it "stops paging once Commons stops offering a cursor" do
    stub_commons([page(title: "File:Akita logo.jpg")])

    expect(candidates).to be_empty
    expect(a_request(:get, /commons\.wikimedia\.org/)).to have_been_made.once
  end

  it "gives up after the page cap rather than paging forever" do
    stub_request(:get, /commons\.wikimedia\.org/).to_return(
      status: 200,
      body: {"query" => {"pages" => {"0" => page(title: "File:Akita logo.jpg")}},
             "continue" => {"gsroffset" => 20}}.to_json,
      headers: {"Content-Type" => "application/json"}
    )

    expect(candidates).to be_empty
    expect(a_request(:get, /commons\.wikimedia\.org/)).to have_been_made.times(described_class::MAX_PAGES)
  end

  it "yields lazily, fetching no more pages than the caller consumes" do
    stub_request(:get, /commons\.wikimedia\.org/).to_return(
      status: 200,
      body: {"query" => {"pages" => {"0" => page(title: "File:A.jpg"), "1" => page(title: "File:B.jpg")}},
             "continue" => {"gsroffset" => 20}}.to_json,
      headers: {"Content-Type" => "application/json"}
    )

    taken = []
    described_class.new(breed, limit: 5).candidates.each do |candidate|
      taken << candidate.source_id
      break if taken.size == 1
    end

    expect(taken.size).to eq(1)
    expect(a_request(:get, /commons\.wikimedia\.org/)).to have_been_made.once
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
