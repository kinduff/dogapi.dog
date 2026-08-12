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

  # The importer walks the adapter's candidate enumerator, pulling more only
  # when it still needs images.
  def stub_adapter(*candidates)
    adapter = instance_double(BreedImages::WikimediaCommons, candidates: candidates.each)
    allow(BreedImages::WikimediaCommons).to receive(:new).and_return(adapter)
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

  it "analyzes what it stores so the dimensions are known" do
    stub_adapter(candidate)
    stub_download

    expect(result.imported.first.dimensions).to eq([800, 600])
  end

  it "refuses an image below the quality floor and keeps nothing behind" do
    stub_adapter(candidate)
    stub_download(body: Rails.root.join("spec/fixtures/files/tiny.jpg").binread)

    expect(result.imported).to be_empty
    expect(result.errors.join).to include("at least #{BreedImage::MIN_DIMENSION}px")
    expect(BreedImage.count).to eq(0)
    expect(ActiveStorage::Blob.count).to eq(0)
  end

  describe "reaching the requested count" do
    def working_candidate(index)
      url = "https://upload.wikimedia.org/ok#{index}.jpg"
      stub_request(:get, url).to_return(
        status: 200,
        # Different bytes each time, or the checksum dedupe would skip them.
        body: image_bytes + index.to_s,
        headers: {"Content-Type" => "image/jpeg"}
      )
      candidate(id: "File:Ok#{index}.jpg", url: url)
    end

    def broken_candidate(index)
      url = "https://upload.wikimedia.org/bad#{index}.jpg"
      stub_request(:get, url).to_return(status: 404, body: "")
      candidate(id: "File:Bad#{index}.jpg", url: url)
    end

    it "keeps pulling candidates until it has as many images as asked for" do
      stub_adapter(broken_candidate(1), broken_candidate(2), working_candidate(3), working_candidate(4))

      result = described_class.call(breed, limit: 2)

      expect(result.imported.size).to eq(2)
      expect(result.errors.size).to eq(2)
    end

    it "stops as soon as the target is met, leaving the rest untouched" do
      stub_adapter(working_candidate(1), working_candidate(2), working_candidate(3))

      described_class.call(breed, limit: 2)

      expect(a_request(:get, "https://upload.wikimedia.org/ok3.jpg")).not_to have_been_made
    end

    it "settles for fewer when the source runs out" do
      stub_adapter(working_candidate(1), broken_candidate(2))

      result = described_class.call(breed, limit: 5)

      expect(result.imported.size).to eq(1)
    end

    it "counts the images the breed already has toward the target" do
      create(:breed_image, breed: breed, source_id: "File:Existing.jpg")
      stub_adapter(working_candidate(1), working_candidate(2))

      result = described_class.call(breed, limit: 2)

      expect(result.imported.size).to eq(1)
      expect(breed.reload.breed_images.count).to eq(2)
    end

    it "does nothing when the breed already has enough" do
      create(:breed_image, breed: breed, source_id: "File:Existing.jpg")
      stub_adapter(working_candidate(1))

      result = described_class.call(breed, limit: 1)

      expect(result.imported).to be_empty
      expect(a_request(:get, /upload\.wikimedia\.org/)).not_to have_been_made
    end

    it "does not count images rejected by the quality floor" do
      tiny = "https://upload.wikimedia.org/tiny.jpg"
      stub_request(:get, tiny).to_return(
        status: 200,
        body: Rails.root.join("spec/fixtures/files/tiny.jpg").binread,
        headers: {"Content-Type" => "image/jpeg"}
      )
      stub_adapter(candidate(id: "File:Tiny.jpg", url: tiny), working_candidate(1))

      result = described_class.call(breed, limit: 1)

      expect(result.imported.size).to eq(1)
      expect(result.imported.first.source_id).to eq("File:Ok1.jpg")
    end
  end

  it "records an adapter failure instead of raising" do
    allow(BreedImages::WikimediaCommons).to receive(:new).and_raise(BreedImages::Downloader::Error, "503 from Commons")

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
