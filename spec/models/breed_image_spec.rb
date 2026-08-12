# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImage do
  subject(:breed_image) { build(:breed_image) }

  it { is_expected.to belong_to(:breed) }
  it { is_expected.to validate_presence_of(:source) }
  it { is_expected.to validate_presence_of(:source_url) }
  it { is_expected.to validate_presence_of(:license) }

  it "is valid with an attached image" do
    expect(breed_image).to be_valid
  end

  it "rejects a duplicate of the same source file" do
    create(:breed_image, source: "wikimedia_commons", source_id: "File:Akita.jpg")
    duplicate = build(:breed_image, source: "wikimedia_commons", source_id: "File:Akita.jpg")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:source_id]).to be_present
  end

  it "allows the same id from a different source" do
    create(:breed_image, source: "wikimedia_commons", source_id: "File:Akita.jpg")
    other = build(:breed_image, source: "manual", source_id: "File:Akita.jpg")

    expect(other).to be_valid
  end

  it "requires a file" do
    breed_image.file.detach

    expect(breed_image).not_to be_valid
    expect(breed_image.errors[:file]).to include("must be attached")
  end

  it "rejects a file that is not a supported image" do
    breed_image.file.attach(
      io: Rails.root.join("spec/fixtures/files/not_an_image.txt").open,
      filename: "not_an_image.txt",
      content_type: "text/plain"
    )

    expect(breed_image).not_to be_valid
    expect(breed_image.errors[:file].join).to include("must be one of")
  end

  describe "dimension floor" do
    # Attaching to an unsaved record does not upload anything, and analyze
    # needs bytes on the service to look at.
    def attach(fixture, breed_image = subject)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: Rails.root.join("spec/fixtures/files/#{fixture}").open,
        filename: fixture,
        content_type: "image/jpeg"
      )
      blob.analyze
      breed_image.file.attach(blob)
      breed_image
    end

    it "accepts an analyzed image above the floor" do
      expect(attach("dog.jpg")).to be_valid
    end

    it "rejects an icon sized image" do
      breed_image = attach("tiny.jpg")

      expect(breed_image).not_to be_valid
      expect(breed_image.errors[:file].join).to include("at least #{described_class::MIN_DIMENSION}px")
    end

    it "rejects an image with too few pixels" do
      breed_image = build(:breed_image)
      allow(breed_image.file.blob).to receive(:metadata).and_return({"width" => 420, "height" => 420})

      expect(breed_image).not_to be_valid
      expect(breed_image.errors[:file].join).to include("pixels")
    end

    it "rejects a panorama" do
      breed_image = build(:breed_image)
      allow(breed_image.file.blob).to receive(:metadata).and_return({"width" => 4000, "height" => 600})

      expect(breed_image).not_to be_valid
      expect(breed_image.errors[:file].join).to include("too far from square")
    end

    it "says nothing about a blob that has not been analyzed" do
      breed_image = build(:breed_image)

      expect(breed_image.dimensions).to be_nil
      expect(breed_image).to be_valid
    end
  end

  it "rejects a file over the size limit" do
    allow(breed_image.file.blob).to receive(:byte_size).and_return(described_class::MAX_BYTE_SIZE + 1)

    expect(breed_image).not_to be_valid
    expect(breed_image.errors[:file].join).to include("smaller than")
  end

  describe "#url_for" do
    subject(:breed_image) { create(:breed_image) }

    it "returns the original url without a variant" do
      expect(breed_image.url_for).to include(breed_image.file.filename.to_s)
    end

    it "returns a variant url for a known size" do
      expect(breed_image.url_for(:thumb)).to be_present
    end

    it "is nil when nothing is attached" do
      breed_image.file.detach

      expect(breed_image.url_for).to be_nil
    end

    it "swaps in the public host when one is configured" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("S3_PUBLIC_HOST").and_return("cdn.dogapi.dog")

      expect(breed_image.url_for).to start_with("https://cdn.dogapi.dog/")
    end
  end

  describe "#attribution" do
    it "prefers the source page over the direct file url" do
      breed_image = build(:breed_image, page_url: "https://commons.wikimedia.org/wiki/File:A.jpg")

      expect(breed_image.attribution[:source_url]).to eq("https://commons.wikimedia.org/wiki/File:A.jpg")
    end

    it "falls back to the file url" do
      breed_image = build(:breed_image, page_url: nil, source_url: "https://example.com/a.jpg")

      expect(breed_image.attribution[:source_url]).to eq("https://example.com/a.jpg")
    end
  end
end
