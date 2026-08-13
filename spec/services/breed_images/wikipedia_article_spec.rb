# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImages::WikipediaArticle do
  subject(:candidates) { described_class.call(breed, limit: 5) }

  let(:breed) { build(:breed, name: "Akita", other_names: []) }

  # The English article carries both the first set of files and the links to
  # every translation of itself.
  def stub_english(files, langlinks: {}, title: "Akita")
    page = {"title" => title}
    page["images"] = files.map { |file| {"title" => file} } if files
    page["langlinks"] = langlinks.map { |lang, name| {"lang" => lang.to_s, "*" => name} } if langlinks.any?
    page["missing"] = "" if files.nil?

    stub_request(:get, "https://en.wikipedia.org/w/api.php")
      .with(query: hash_including("titles" => title, "prop" => "images|langlinks"))
      .to_return(
        status: 200,
        body: {"query" => {"pages" => {"1" => page}}}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  def stub_translation(language, title, files)
    stub_request(:get, "https://#{language}.wikipedia.org/w/api.php")
      .with(query: hash_including("titles" => title))
      .to_return(
        status: 200,
        body: {"query" => {"pages" => {"1" => {
          "title" => title,
          "images" => files.map { |file| {"title" => file} }
        }}}}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  def stub_commons(*titles, width: 1200, height: 900)
    pages = titles.each_with_index.to_h do |title, index|
      [index.to_s, {
        "title" => title,
        "imageinfo" => [{
          "url" => "https://upload.wikimedia.org/#{title.delete_prefix("File:")}",
          "descriptionurl" => "https://commons.wikimedia.org/wiki/#{title}",
          "mime" => "image/jpeg",
          "width" => width,
          "height" => height,
          "size" => 500_000,
          "extmetadata" => {
            "Artist" => {"value" => "Jane"},
            "LicenseShortName" => {"value" => "CC BY-SA 4.0"},
            "LicenseUrl" => {"value" => "https://creativecommons.org/licenses/by-sa/4.0/"}
          }
        }]
      }]
    end

    stub_request(:get, /commons\.wikimedia\.org/).to_return(
      status: 200,
      body: {"query" => {"pages" => pages}}.to_json,
      headers: {"Content-Type" => "application/json"}
    )
  end

  # No article under the breed's own name, and a search that finds nothing:
  # the examples below fill in whichever of the two they are about.
  before do
    stub_english(nil)
    stub_request(:get, "https://en.wikipedia.org/w/api.php")
      .with(query: hash_including("list" => "search"))
      .to_return(
        status: 200,
        body: {"query" => {"search" => []}}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  it "takes every picture the article uses, in the order it uses them" do
    stub_english(["File:Akita head.jpg", "File:Akita standing.jpg"])
    stub_commons("File:Akita standing.jpg", "File:Akita head.jpg")

    expect(candidates.map(&:source_id)).to eq(["File:Akita head.jpg", "File:Akita standing.jpg"])
  end

  it "credits them from Commons like every other file from there" do
    stub_english(["File:Akita head.jpg"])
    stub_commons("File:Akita head.jpg")

    expect(candidates.first).to have_attributes(
      source: "wikimedia_commons",
      author: "Jane",
      license: "CC BY-SA 4.0"
    )
  end

  it "follows the article's own language links to the translations" do
    stub_english(["File:Akita head.jpg"], langlinks: {de: "Akita Inu"})
    stub_translation("de", "Akita Inu", ["File:Akita im Schnee.jpg"])
    stub_commons("File:Akita head.jpg", "File:Akita im Schnee.jpg")

    expect(candidates.map(&:source_id))
      .to contain_exactly("File:Akita head.jpg", "File:Akita im Schnee.jpg")
  end

  it "never offers a file two Wikipedias share twice" do
    stub_english(["File:Akita head.jpg"], langlinks: {de: "Akita Inu"})
    stub_translation("de", "Akita Inu", ["File:Akita head.jpg"])
    stub_commons("File:Akita head.jpg")

    expect(candidates.size).to eq(1)
  end

  it "ignores the furniture an article carries" do
    stub_english(["File:Commons-logo.svg", "File:Flag of Japan.svg", "File:Akita bark.ogg"])

    expect(candidates).to be_empty
  end

  it "applies the same quality floor as every other Commons source" do
    stub_english(["File:Akita head.jpg"])
    stub_commons("File:Akita head.jpg", width: 200, height: 150)

    expect(candidates).to be_empty
  end

  it "carries on when a translation's Wikipedia is unreachable" do
    stub_english(["File:Akita head.jpg"], langlinks: {de: "Akita Inu"})
    stub_request(:get, /de\.wikipedia\.org/).to_return(status: 503, body: "")
    stub_commons("File:Akita head.jpg")

    expect(candidates.size).to eq(1)
  end

  it "yields nothing when no article about the breed exists" do
    expect(candidates).to be_empty
  end
end
