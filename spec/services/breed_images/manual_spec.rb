# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImages::Manual do
  subject(:candidates) { described_class.call(breed, limit: 2) }

  let(:breed) { build(:breed, name: "Akita") }
  let(:catalog) do
    {
      "Akita" => [
        {"url" => "https://example.com/akita.jpg", "author" => "Jane", "license" => "CC BY 4.0",
         "license_url" => "https://creativecommons.org/licenses/by/4.0/", "page_url" => "https://example.com/akita"},
        {"url" => "https://example.com/akita-2.jpg", "id" => "akita-2", "license" => "CC0"},
        {"url" => "https://example.com/no-license.jpg"}
      ]
    }
  end

  before do
    allow(described_class::CATALOG_PATH).to receive(:exist?).and_return(true)
    allow(YAML).to receive(:safe_load_file).with(described_class::CATALOG_PATH).and_return(catalog)
  end

  it "maps catalog entries into candidates" do
    expect(candidates.map(&:source_id)).to eq(["https://example.com/akita.jpg", "akita-2"])
    expect(candidates.first).to have_attributes(
      source: "manual",
      author: "Jane",
      license: "CC BY 4.0",
      filename: "akita.jpg"
    )
  end

  it "skips entries without a licence" do
    expect(candidates.map(&:source_url)).not_to include("https://example.com/no-license.jpg")
  end

  it "returns nothing for a breed that is not in the catalog" do
    expect(described_class.call(build(:breed, name: "Beagle"))).to be_empty
  end

  it "returns nothing when there is no catalog file" do
    allow(described_class::CATALOG_PATH).to receive(:exist?).and_return(false)

    expect(candidates).to be_empty
  end
end
