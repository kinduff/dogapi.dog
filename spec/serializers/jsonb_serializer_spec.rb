# frozen_string_literal: true

require "rails_helper"

describe JsonbSerializer do
  describe ".dump" do
    it "returns the hash as a JSON string" do
      hash = {"key" => "value"}
      expect(described_class.dump(hash)).to eq '{"key":"value"}'
    end
  end

  describe ".load" do
    it "returns an empty hash if the input is nil" do
      expect(described_class.load(nil)).to eq({})
    end

    it "returns the input hash if it is empty" do
      hash = {}
      expect(described_class.load(hash)).to eq hash
    end

    it "parses the input JSON string and returns the resulting hash" do
      json = '{"key":"value"}'
      expect(described_class.load(json)).to eq({"key" => "value"})
    end
  end
end
