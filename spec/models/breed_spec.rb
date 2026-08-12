# frozen_string_literal: true

require "rails_helper"

RSpec.describe Breed do
  it { is_expected.to belong_to(:group) }
  it { is_expected.to have_many(:breed_images).dependent(:destroy) }
  it { is_expected.to have_many(:breed_enrichments).dependent(:destroy) }

  describe "#primary_image" do
    let(:breed) { create(:breed) }

    it "returns the lowest positioned image" do
      second = create(:breed_image, breed: breed, position: 2)
      first = create(:breed_image, breed: breed, position: 1)

      expect(breed.reload.primary_image).to eq(first)
      expect(breed.breed_images.last).to eq(second)
    end

    it "is nil without images" do
      expect(breed.primary_image).to be_nil
    end
  end

  describe "store accessors" do
    let(:breed) { build(:breed, life: {"min" => 10, "max" => 14}) }

    it "reads the prefixed life range" do
      expect([breed.life_min, breed.life_max]).to eq([10, 14])
    end

    it "writes back into the jsonb column" do
      breed.male_weight_min = 30
      breed.male_weight_max = 40

      expect(breed.male_weight).to eq("min" => 30, "max" => 40)
    end

    it "keeps the three ranges separate" do
      breed.female_weight_min = 25

      expect(breed.male_weight_min).to be_nil
    end

    it "writes the enrichment columns" do
      breed.male_height_min = 55
      breed.origin_country = "Thailand"
      breed.coat_colors = %w[red black]
      breed.traits_energy = 4

      expect(breed.male_height).to eq("min" => 55)
      expect(breed.origin).to eq("country" => "Thailand")
      expect(breed.coat).to eq("colors" => %w[red black])
      expect(breed.traits).to eq("energy" => 4)
    end
  end

  describe "scopes" do
    it "splits breeds by whether they have been enriched" do
      enriched = create(:breed, enriched_at: Time.current)
      untouched = create(:breed)

      expect(described_class.enriched).to eq([enriched])
      expect(described_class.unenriched).to eq([untouched])
    end
  end

  describe "defaults" do
    it "is not hypoallergenic" do
      expect(create(:breed).hypoallergenic).to be(false)
    end
  end
end
