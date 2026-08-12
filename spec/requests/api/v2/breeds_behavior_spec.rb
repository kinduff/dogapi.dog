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
        %w[name description life male_weight female_weight hypoallergenic images
          male_height female_height origin coat traits other_names recognized_by sources]
      )
    end

    context "with filter[has_images]" do
      it "keeps only the breeds that have a picture" do
        pictured = create(:breed, name: "Akita", group: group)
        create(:breed_image, breed: pictured)
        create(:breed, name: "Beagle", group: group)

        get "/api/v2/breeds", params: {filter: {has_images: "true"}}

        expect(json["data"].map { |breed| breed.dig("attributes", "name") }).to eq(["Akita"])
      end

      # A breed with three pictures is still one record.
      it "returns a breed once however many pictures it has" do
        pictured = create(:breed, name: "Akita", group: group)
        create(:breed_image, breed: pictured, source_id: "File:One.jpg")
        create(:breed_image, breed: pictured, source_id: "File:Two.jpg")

        get "/api/v2/breeds", params: {filter: {has_images: "true"}}

        expect(json["data"].size).to eq(1)
        expect(json.dig("meta", "pagination", "records")).to eq(1)
      end

      # Cast the same way as `random` on the image endpoint, so one false value
      # means the same thing everywhere in this API.
      it "leaves the collection alone when asked for false" do
        create(:breed, name: "Beagle", group: group)

        get "/api/v2/breeds", params: {filter: {has_images: "false"}}

        expect(json["data"].size).to eq(1)
      end
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
