# frozen_string_literal: true

require "rails_helper"

RSpec.describe Breed do
  it { is_expected.to belong_to(:group) }
  it { is_expected.to have_many(:breed_images).dependent(:destroy) }

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
  end

  describe "defaults" do
    it "is not hypoallergenic" do
      expect(create(:breed).hypoallergenic).to be(false)
    end
  end
end
