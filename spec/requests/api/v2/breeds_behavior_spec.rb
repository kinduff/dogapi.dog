# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V2::Breeds" do
  let(:group) { create(:group, name: "Working") }

  def json
    JSON.parse(response.body)
  end

  describe "GET /api/v2/breeds" do
    it "orders breeds by name" do
      create(:breed, name: "Zuchon", group: group)
      create(:breed, name: "Akita", group: group)

      get "/api/v2/breeds"

      expect(json["data"].map { |b| b.dig("attributes", "name") }).to eq(%w[Akita Zuchon])
    end

    it "serializes the documented attributes" do
      create(:breed, name: "Akita", description: "A large breed", hypoallergenic: false, group: group)

      get "/api/v2/breeds"

      expect(json["data"].first["attributes"].keys).to match_array(
        %w[name description life male_weight female_weight hypoallergenic images]
      )
    end

    it "links each breed to its group" do
      breed = create(:breed, group: group)

      get "/api/v2/breeds"

      expect(json["data"].first.dig("relationships", "group", "data", "id")).to eq(breed.group_id)
    end

    it "returns an empty collection when there are no breeds" do
      get "/api/v2/breeds"

      expect(response).to have_http_status(:ok)
      expect(json["data"]).to eq([])
    end
  end

  describe "GET /api/v2/breeds/:id" do
    it "returns the breed" do
      breed = create(:breed, name: "Akita", group: group)

      get "/api/v2/breeds/#{breed.id}"

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "attributes", "name")).to eq("Akita")
    end

    it "returns 404 for an unknown id" do
      get "/api/v2/breeds/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a malformed id instead of raising" do
      get "/api/v2/breeds/not-a-uuid"

      expect(response).to have_http_status(:not_found)
    end
  end
end
