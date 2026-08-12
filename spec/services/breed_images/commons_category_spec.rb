# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImages::CommonsCategory do
  subject(:candidates) { described_class.call(breed, limit: 3) }

  let(:breed) { build(:breed, name: "Akita", other_names: []) }

  def file_page(title, categories: [], width: 1200, height: 900, mime: "image/jpeg")
    page = {
      "title" => title,
      "imageinfo" => [{
        "url" => "https://upload.wikimedia.org/#{title.delete_prefix("File:")}",
        "descriptionurl" => "https://commons.wikimedia.org/wiki/#{title}",
        "mime" => mime,
        "width" => width,
        "height" => height,
        "size" => 500_000,
        "extmetadata" => {
          "Artist" => {"value" => "Jane"},
          "LicenseShortName" => {"value" => "CC BY-SA 4.0"},
          "LicenseUrl" => {"value" => "https://creativecommons.org/licenses/by-sa/4.0/"}
        }
      }]
    }
    page["categories"] = categories.map { |name| {"title" => name} } if categories.any?
    page
  end

  def stub_commons(query, body)
    stub_request(:get, "https://commons.wikimedia.org/w/api.php")
      .with(query: hash_including(query))
      .to_return(status: 200, body: body.to_json, headers: {"Content-Type" => "application/json"})
  end

  def stub_category(title, exists: true)
    page = exists ? {"title" => title, "categoryinfo" => {"files" => 3}} : {"title" => title, "missing" => ""}

    stub_commons({"titles" => title, "prop" => "categoryinfo"}, {"query" => {"pages" => {"1" => page}}})
  end

  def stub_members(title, pages)
    stub_commons(
      {"gcmtitle" => title, "generator" => "categorymembers"},
      {"query" => {"pages" => pages.each_with_index.to_h { |page, index| [index.to_s, page] }}}
    )
  end

  def stub_subcategories(title, titles)
    stub_commons(
      {"cmtitle" => title, "list" => "categorymembers"},
      {"query" => {"categorymembers" => titles.map { |name| {"title" => name} }}}
    )
  end

  def stub_category_search(*titles)
    stub_commons(
      {"list" => "search"},
      {"query" => {"search" => titles.map { |title| {"title" => title} }}}
    )
  end

  before do
    %w[Category:Akita Category:Akita\ dogs].each { |title| stub_category(title, exists: false) }
    stub_category_search
  end

  it "takes the files a breed's own category holds" do
    stub_category("Category:Akita")
    stub_subcategories("Category:Akita", [])
    stub_members("Category:Akita", [file_page("File:Akita one.jpg")])

    expect(candidates.first).to have_attributes(
      source: "wikimedia_commons",
      source_id: "File:Akita one.jpg",
      author: "Jane",
      license: "CC BY-SA 4.0",
      filename: "Akita_one.jpg"
    )
  end

  it "puts the files Commons has assessed ahead of the rest" do
    stub_category("Category:Akita")
    stub_subcategories("Category:Akita", [])
    stub_members("Category:Akita", [
      file_page("File:Plain.jpg"),
      file_page("File:Quality.jpg", categories: ["Category:Quality images of dogs"])
    ])

    expect(candidates.map(&:source_id)).to eq(["File:Quality.jpg", "File:Plain.jpg"])
  end

  it "descends into the subcategories of a breed's category" do
    stub_category("Category:Akita")
    stub_subcategories("Category:Akita", ["Category:Akita puppies"])
    stub_members("Category:Akita", [file_page("File:Adult.jpg")])
    stub_members("Category:Akita puppies", [file_page("File:Puppy.jpg")])

    expect(candidates.map(&:source_id)).to eq(["File:Adult.jpg", "File:Puppy.jpg"])
  end

  it "never offers the same file twice" do
    stub_category("Category:Akita")
    stub_subcategories("Category:Akita", ["Category:Akita puppies"])
    stub_members("Category:Akita", [file_page("File:Same.jpg")])
    stub_members("Category:Akita puppies", [file_page("File:Same.jpg")])

    expect(candidates.size).to eq(1)
  end

  it "tries the other spellings Commons might have used" do
    stub_category("Category:Akita dogs")
    stub_subcategories("Category:Akita dogs", [])
    stub_members("Category:Akita dogs", [file_page("File:Akita.jpg")])

    expect(candidates.size).to eq(1)
  end

  it "takes the category a search finds, whatever language it is named in" do
    stub_category_search("Category:Akita Inu (犬)")
    stub_subcategories("Category:Akita Inu (犬)", [])
    stub_members("Category:Akita Inu (犬)", [file_page("File:Akita.jpg")])

    expect(candidates.size).to eq(1)
  end

  it "does not descend into a subcategory of skeletons or coats of arms" do
    stub_category("Category:Akita")
    stub_subcategories("Category:Akita", ["Category:Akita skeletons"])
    stub_members("Category:Akita", [file_page("File:Adult.jpg")])

    expect(candidates.map(&:source_id)).to eq(["File:Adult.jpg"])
  end

  it "yields nothing when the breed has no category at all" do
    expect(candidates).to be_empty
  end

  it "applies the same quality floor as a search does" do
    stub_category("Category:Akita")
    stub_subcategories("Category:Akita", [])
    stub_members("Category:Akita", [
      file_page("File:Tiny.jpg", width: 200, height: 150),
      file_page("File:Drawing.svg", mime: "image/svg+xml"),
      file_page("File:Akita map.jpg")
    ])

    expect(candidates).to be_empty
  end
end
