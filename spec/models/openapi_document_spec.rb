# frozen_string_literal: true

require "rails_helper"

RSpec.describe OpenapiDocument do
  subject(:document) { described_class.load("v2") }

  it "raises when the document does not exist" do
    expect { described_class.load("v9") }.to raise_error(described_class::NotFound)
  end

  it "reads the metadata" do
    expect(document.title).to eq("API V2")
    expect(document.base_url).to eq("https://dogapi.dog/api/v2")
    expect(document.document_path).to eq("/api-docs/v2/swagger.json")
  end

  describe "#sections" do
    it "groups the operations under their tag" do
      expect(document.sections.map { |section| section[:name] }).to eq(%w[Breeds Groups Facts])
    end

    it "keeps the tag description" do
      breeds = document.sections.first

      expect(breeds[:description]).to be_present
    end

    it "lists every operation exactly once" do
      paths = document.sections.flat_map { |section| section[:operations] }.map(&:path)

      expect(paths).to contain_exactly("/breeds", "/breeds/{id}", "/groups", "/groups/{id}", "/facts")
    end
  end

  describe "operations" do
    let(:show) { document.operations.find { |operation| operation.path == "/breeds/{id}" } }
    let(:index) { document.operations.find { |operation| operation.path == "/breeds" } }

    it "exposes both documented responses" do
      expect(show.responses.map(&:code)).to eq(%w[200 404])
    end

    it "reads the parameters with their constraints" do
      size = index.parameters.find { |parameter| parameter.name == "page[size]" }

      expect(size.type).to eq("integer")
      expect(size.constraints).to include("min 1", "max 1000")
    end

    it "builds a unique anchor per operation" do
      anchors = document.operations.map(&:anchor)

      expect(anchors).to eq(anchors.uniq)
    end

    it "carries the response example" do
      response = index.responses.first

      expect(response.example.dig("data", 0, "attributes", "name")).to eq("Caucasian Shepherd Dog")
    end
  end

  describe "#models" do
    it "lists the reusable schemas" do
      expect(document.models).to contain_exactly("Range", "PaginationMeta", "Breed", "Group", "Fact")
    end

    it "leaves out the envelope wrappers" do
      expect(document.models).not_to include("BreedCollection", "BreedResource")
    end
  end

  describe "#fields" do
    it "walks nested objects with a dotted path" do
      paths = document.model_fields("Breed").map(&:path)

      expect(paths).to include("attributes.name", "relationships.group.data.id")
    end

    it "stops at a reference and links to it instead" do
      life = document.model_fields("Breed").find { |field| field.path == "attributes.life" }

      expect(life.reference).to eq("Range")
      expect(document.model_fields("Breed").map(&:path)).not_to include("attributes.life.min")
    end

    it "labels arrays by what they contain" do
      collection = document.fields({"$ref": "#/components/schemas/BreedCollection"}.stringify_keys)
      data = collection.find { |field| field.path == "data" }

      expect(data.type).to eq("array of Breed")
    end

    it "handles a document without components" do
      expect(described_class.load("v1").models).to be_empty
    end
  end
end
