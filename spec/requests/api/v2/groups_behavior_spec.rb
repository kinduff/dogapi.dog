# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V2::Groups" do
  def json
    JSON.parse(response.body)
  end

  describe "GET /api/v2/groups" do
    it "orders groups by name" do
      create(:group, name: "Working")
      create(:group, name: "Herding")

      get "/api/v2/groups"

      expect(json["data"].map { |g| g.dig("attributes", "name") }).to eq(%w[Herding Working])
    end

    it "links each group to its breeds" do
      group = create(:group)
      breed = create(:breed, group: group)

      get "/api/v2/groups"

      ids = json["data"].first.dig("relationships", "breeds", "data").map { |b| b["id"] }
      expect(ids).to eq([breed.id])
    end

    it "returns an empty collection when there are no groups" do
      get "/api/v2/groups"

      expect(response).to have_http_status(:ok)
      expect(json["data"]).to eq([])
    end
  end

  describe "GET /api/v2/groups/:id" do
    it "returns the group" do
      group = create(:group, name: "Working")

      get "/api/v2/groups/#{group.id}"

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "attributes", "name")).to eq("Working")
    end

    it "returns 404 for an unknown id" do
      get "/api/v2/groups/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a malformed id instead of raising" do
      get "/api/v2/groups/not-a-uuid"

      expect(response).to have_http_status(:not_found)
    end
  end
end
