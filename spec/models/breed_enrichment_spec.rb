# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedEnrichment do
  it { is_expected.to belong_to(:breed) }
  it { is_expected.to validate_presence_of(:model) }

  describe "scopes" do
    it "separates applied runs from rejected ones" do
      applied = create(:breed_enrichment, applied_at: Time.current)
      rejected = create(:breed_enrichment)

      expect(described_class.applied).to eq([applied])
      expect(described_class.rejected).to eq([rejected])
    end

    it "orders newest first" do
      older = create(:breed_enrichment, created_at: 2.days.ago)
      newer = create(:breed_enrichment)

      expect(described_class.ordered).to eq([newer, older])
    end
  end
end
