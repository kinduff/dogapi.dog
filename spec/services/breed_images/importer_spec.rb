# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImages::Importer do
  subject(:result) { described_class.call(breed, limit: 2) }

  let(:breed) { create(:breed, name: "Akita") }
  let(:image_bytes) { Rails.root.join("spec/fixtures/files/dog.jpg").binread }

  def candidate(id: "File:Akita.jpg", url: "https://upload.wikimedia.org/akita.jpg")
    BreedImages::Candidate.new(
      source: "wikimedia_commons",
      source_id: id,
      source_url: url,
      page_url: "https://commons.wikimedia.org/wiki/#{id}",
      author: "Jane",
      license: "CC BY-SA 4.0",
      license_url: "https://creativecommons.org/licenses/by-sa/4.0/",
      filename: "akita.jpg"
    )
  end

  def stub_adapter(*candidates)
    allow(BreedImages::WikimediaCommons).to receive(:call).and_return(candidates)
  end

  def stub_download(url: "https://upload.wikimedia.org/akita.jpg", body: image_bytes)
    stub_request(:get, url).to_return(status: 200, body: body, headers: {"Content-Type" => "image/jpeg"})
  end

  it "stores the image with its attribution" do
    stub_adapter(candidate)
    stub_download

    expect(result.imported.size).to eq(1)
    image = breed.reload.breed_images.first
    expect(image).to have_attributes(
      source: "wikimedia_commons",
      source_id: "File:Akita.jpg",
      author: "Jane",
      license: "CC BY-SA 4.0",
      position: 1
    )
    expect(image.file).to be_attached
    expect(image.file.filename.to_s).to eq("akita.jpg")
  end

  it "processes the variants up front" do
    stub_adapter(candidate)
    stub_download

    image = result.imported.first

    expect(BreedImage::VARIANTS.keys).to all(satisfy { |name| image.file.variant(name).send(:processed?) })
  end

  it "numbers positions from the highest existing one" do
    existing = create(:breed_image, breed: breed, position: 7)
    existing.file.attach(
      io: Rails.root.join("spec/fixtures/files/dog_alt.jpg").open,
      filename: "other.jpg",
      content_type: "image/jpeg"
    )
    stub_adapter(candidate)
    stub_download

    expect(result.imported.first.position).to eq(8)
  end

  it "skips a candidate that was already imported" do
    create(:breed_image, breed: breed, source: "wikimedia_commons", source_id: "File:Akita.jpg")
    stub_adapter(candidate)

    expect(result.imported).to be_empty
    expect(result.skipped).to eq(["File:Akita.jpg"])
    expect(a_request(:get, /upload\.wikimedia\.org/)).not_to have_been_made
  end

  it "skips a byte identical file that arrived under another title" do
    stub_adapter(candidate, candidate(id: "File:Akita 2.jpg", url: "https://upload.wikimedia.org/akita2.jpg"))
    stub_download
    stub_download(url: "https://upload.wikimedia.org/akita2.jpg")

    expect(result.imported.size).to eq(1)
    expect(result.skipped).to eq(["File:Akita 2.jpg"])
    expect(breed.reload.breed_images.count).to eq(1)
  end

  it "is a no-op on a second run" do
    stub_adapter(candidate)
    stub_download
    described_class.call(breed, limit: 2)

    expect { described_class.call(breed, limit: 2) }.not_to change(BreedImage, :count)
  end

  it "records a failed download and keeps going" do
    stub_adapter(candidate, candidate(id: "File:Akita 2.jpg", url: "https://upload.wikimedia.org/akita2.jpg"))
    stub_request(:get, "https://upload.wikimedia.org/akita.jpg").to_return(status: 404, body: "")
    stub_download(url: "https://upload.wikimedia.org/akita2.jpg")

    expect(result.imported.size).to eq(1)
    expect(result.errors.join).to include("404")
  end

  it "records an adapter failure instead of raising" do
    allow(BreedImages::WikimediaCommons).to receive(:call).and_raise(BreedImages::Downloader::Error, "503 from Commons")

    expect(result.imported).to be_empty
    expect(result.errors.join).to include("503 from Commons")
  end

  it "rejects an unknown source" do
    expect { described_class.call(breed, source: "flickr") }
      .to raise_error(ArgumentError, /unknown image source/)
  end

  it "summarises what happened" do
    stub_adapter(candidate)
    stub_download

    expect(result.summary).to eq("1 imported, 0 skipped, 0 failed")
  end
end
