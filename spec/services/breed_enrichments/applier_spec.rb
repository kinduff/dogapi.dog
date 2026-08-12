# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedEnrichments::Applier do
  subject(:record) { described_class.call(breed, validation, raw: raw, **options) }

  let(:breed) { create(:breed, name: "Akita") }
  let(:options) { {} }
  let(:payload) do
    {
      "male_height" => {"min" => 66, "max" => 71},
      "origin" => {"country" => "Japan"},
      "sources" => [{"url" => "https://www.akc.org/dog-breeds/akita/"}]
    }
  end
  let(:raw) { payload.merge("name" => "Akita", "confidence" => "high") }
  let(:validation) { BreedEnrichments::Validator::Result.new(payload, [], nil) }

  it "fills in the breed and records the run" do
    expect(record).to be_persisted
    expect(record).to be_applied
    expect(record.confidence).to eq("high")

    breed.reload
    expect(breed.male_height).to eq("min" => 66, "max" => 71)
    expect(breed.origin_country).to eq("Japan")
    expect(breed.enrichment_model).to eq(BreedEnrichments.model)
    expect(breed.enriched_at).to be_present
  end

  it "leaves the data that was already there alone" do
    expect { record }.not_to change { breed.reload.slice(:description, :life, :male_weight) }
  end

  context "when a column is already filled in" do
    let(:breed) { create(:breed, name: "Akita", origin: {"country" => "Nowhere"}) }

    it "keeps what is there" do
      expect(record.payload["changes"]).not_to have_key("origin")
      expect(breed.reload.origin_country).to eq("Nowhere")
    end

    context "and the caller asked to overwrite" do
      let(:options) { {overwrite: true} }

      it "replaces it and says what it replaced" do
        expect(record.payload.dig("changes", "origin", "from")).to eq("country" => "Nowhere")
        expect(breed.reload.origin_country).to eq("Japan")
      end
    end
  end

  context "on a dry run" do
    let(:options) { {dry_run: true} }

    it "writes nothing" do
      expect(record).not_to be_persisted
      expect(record.payload["changes"]).to have_key("male_height")
      expect(breed.reload.male_height).to eq({})
      expect(BreedEnrichment.count).to eq(0)
    end
  end

  context "when the answer failed validation outright" do
    let(:validation) { BreedEnrichments::Validator::Result.new({}, [], "no usable sources") }

    it "records the failure without touching the breed" do
      expect(record).to be_persisted
      expect(record).not_to be_applied
      expect(record.rejections.last["reason"]).to eq("no usable sources")
      expect(breed.reload.enriched_at).to be_nil
    end
  end
end
