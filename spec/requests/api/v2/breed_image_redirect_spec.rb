# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V2::Breeds image redirect" do
  let(:breed) { create(:breed, name: "Akita") }

  # Disk service URLs embed a signed, expiring token, so two URLs for the same
  # file are never string equal. Compare the blob key they point at instead.
  def redirected_key
    token = URI.parse(response.headers.fetch("Location")).path.split("/")[4]

    ActiveStorage.verifier.verified(token, purpose: :blob_key)&.fetch("key")
  end

  def key_of(breed_image, size = nil)
    blob = size.nil? ? breed_image.file.blob : breed_image.file.variant(size).processed.image.blob

    blob.key
  end

  describe "GET /api/v2/breeds/:id/image" do
    it "redirects to the primary image" do
      create(:breed_image, breed: breed, position: 2, source_id: "File:B.jpg")
      first = create(:breed_image, breed: breed, position: 1, source_id: "File:A.jpg")

      get "/api/v2/breeds/#{breed.id}/image"

      expect(response).to have_http_status(:found)
      expect(redirected_key).to eq(key_of(first, :medium))
    end

    it "serves the requested size" do
      image = create(:breed_image, breed: breed)

      get "/api/v2/breeds/#{breed.id}/image", params: {size: "thumb"}

      expect(redirected_key).to eq(key_of(image, :thumb))
    end

    it "serves the original for size=full" do
      image = create(:breed_image, breed: breed)

      get "/api/v2/breeds/#{breed.id}/image", params: {size: "full"}

      expect(redirected_key).to eq(key_of(image))
    end

    it "falls back to the default size for an unknown one" do
      image = create(:breed_image, breed: breed)

      get "/api/v2/breeds/#{breed.id}/image", params: {size: "gigantic"}

      expect(redirected_key).to eq(key_of(image, :medium))
    end

    it "picks any of the breed's images with random=true" do
      images = 2.times.map { |i| create(:breed_image, breed: breed, position: i, source_id: "File:#{i}.jpg") }

      get "/api/v2/breeds/#{breed.id}/image", params: {random: "true"}

      expect(images.map { |image| key_of(image, :medium) }).to include(redirected_key)
    end

    it "is publicly cacheable" do
      create(:breed_image, breed: breed)

      get "/api/v2/breeds/#{breed.id}/image"

      expect(response.headers["Cache-Control"]).to include("public")
    end

    it "returns 404 for a breed without images" do
      get "/api/v2/breeds/#{breed.id}/image"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an unknown breed" do
      get "/api/v2/breeds/#{SecureRandom.uuid}/image"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a malformed id instead of raising" do
      get "/api/v2/breeds/not-a-uuid/image"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v2/breeds/image" do
    it "redirects to an image from any breed" do
      image = create(:breed_image, breed: breed)

      get "/api/v2/breeds/image"

      expect(response).to have_http_status(:found)
      expect(redirected_key).to eq(key_of(image, :medium))
    end

    it "honours the size parameter" do
      image = create(:breed_image, breed: breed)

      get "/api/v2/breeds/image", params: {size: "large"}

      expect(redirected_key).to eq(key_of(image, :large))
    end

    it "returns 404 when nothing has been imported yet" do
      get "/api/v2/breeds/image"

      expect(response).to have_http_status(:not_found)
    end
  end
end
