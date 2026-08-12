# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedEnrichments::Validator do
  subject(:result) { described_class.call(breed, attributes) }

  let(:breed) do
    create(:breed, name: "Akita", male_weight: {"min" => 32, "max" => 59}, female_weight: {"min" => 32, "max" => 45})
  end

  let(:sources) { [{"url" => "https://www.akc.org/dog-breeds/akita/", "title" => "AKC"}] }

  def answer(overrides = {})
    {"name" => "Akita", "sources" => sources, "confidence" => "high"}.merge(overrides)
  end

  describe "the answer as a whole" do
    let(:attributes) { answer }

    it "keeps the sources it can check" do
      expect(result).to be_valid
      expect(result.payload["sources"]).to eq([{"url" => "https://www.akc.org/dog-breeds/akita/", "title" => "AKC"}])
    end

    context "when the model researched a different breed" do
      let(:attributes) { answer("name" => "Shiba Inu") }

      it "throws the whole answer away" do
        expect(result).not_to be_valid
        expect(result.fatal).to include("Shiba Inu")
        expect(result.payload).to be_empty
      end
    end

    context "without a usable source" do
      let(:sources) { [{"url" => "somewhere on the internet"}] }

      it "throws the whole answer away" do
        expect(result).not_to be_valid
        expect(result.fatal).to eq("no usable sources")
      end
    end
  end

  describe "heights" do
    context "with a plausible range" do
      let(:attributes) { answer("male_height" => {"min" => 66.0, "max" => 71.4}) }

      it "rounds to whole centimetres" do
        expect(result.payload["male_height"]).to eq("min" => 66, "max" => 71)
      end
    end

    context "with an inverted range" do
      let(:attributes) { answer("male_height" => {"min" => 71, "max" => 66}) }

      it "drops it" do
        expect(result.payload).not_to have_key("male_height")
        expect(result.rejections.first[:reason]).to eq("min above max")
      end
    end

    context "with a height that cannot belong to a dog of that weight" do
      let(:attributes) { answer("male_height" => {"min" => 22, "max" => 25}) }

      it "drops it rather than believing a 25cm tall Akita" do
        expect(result.payload).not_to have_key("male_height")
        expect(result.rejections.first[:reason]).to include("stored weight")
      end
    end

    context "when the breed has no stored weight to check against" do
      let(:breed) { create(:breed, name: "Akita", male_weight: {}, female_weight: {}) }
      let(:attributes) { answer("male_height" => {"min" => 22, "max" => 25}) }

      it "accepts the height" do
        expect(result.payload["male_height"]).to eq("min" => 22, "max" => 25)
      end
    end
  end

  describe "traits" do
    let(:attributes) do
      answer("traits" => {
        "energy" => 4,
        "barking" => 9,
        "exercise_minutes" => 600,
        "temperament" => ["loyal", "  ", "dignified"]
      })
    end

    it "keeps the ratings on the scale and drops the rest" do
      expect(result.payload["traits"]).to eq("energy" => 4, "temperament" => %w[loyal dignified])
      expect(result.rejections.map { |rejection| rejection[:field] })
        .to contain_exactly("traits.barking", "traits.exercise_minutes")
    end
  end

  describe "enumerated values" do
    let(:attributes) do
      answer(
        "coat" => {"type" => "double", "length" => "fluffy", "colors" => %w[red brindle]},
        "recognized_by" => %w[AKC SPACE-DOGS AKC]
      )
    end

    it "keeps only the values the API is willing to serve" do
      expect(result.payload["coat"]).to eq("type" => "double", "colors" => %w[red brindle])
      expect(result.payload["recognized_by"]).to eq(%w[AKC])
    end
  end

  describe "origin" do
    context "without a country" do
      let(:attributes) { answer("origin" => {"era" => "17th century"}) }

      it "drops it" do
        expect(result.payload).not_to have_key("origin")
        expect(result.rejections.first[:reason]).to eq("no country")
      end
    end
  end
end
