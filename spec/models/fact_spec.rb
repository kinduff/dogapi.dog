# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fact do
  describe ".random" do
    it "returns nothing when there are no facts" do
      expect(described_class.random).to be_empty
    end

    it "returns a single fact by default" do
      create_list(:fact, 3)

      expect(described_class.random.size).to eq(1)
    end

    it "returns the requested number of facts" do
      create_list(:fact, 3)

      expect(described_class.random(2).size).to eq(2)
    end

    it "never returns more facts than exist" do
      create(:fact)

      expect(described_class.random(5).size).to eq(1)
    end

    it "only returns persisted facts" do
      facts = create_list(:fact, 3)

      expect(described_class.random(3).map(&:id)).to match_array(facts.map(&:id))
    end

    it "does not sort the table at the database level" do
      create_list(:fact, 3)

      expect(described_class.random(2).to_sql).not_to include("RANDOM()")
    end
  end

  describe ".cached_ids" do
    it "is expired when a fact is created" do
      create(:fact)
      cache = ActiveSupport::Cache::MemoryStore.new

      allow(Rails).to receive(:cache).and_return(cache)
      expect(described_class.cached_ids.size).to eq(1)

      create(:fact)

      expect(described_class.cached_ids.size).to eq(2)
    end
  end
end
