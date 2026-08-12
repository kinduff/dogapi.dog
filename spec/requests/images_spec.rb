# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Images page" do
  let(:group) { create(:group, name: "Working Group") }
  let!(:with_image) { create(:breed, name: "Akita", group: group) }
  let!(:without_image) { create(:breed, name: "Beagle", group: group) }

  before do
    Rails.cache.clear
    create(:breed_image, breed: with_image, author: "Jane", license: "CC BY-SA 4.0")
  end

  it "renders the gallery" do
    get "/images"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Akita", "Beagle")
  end

  it "shows a placeholder for a breed without images" do
    get "/images"

    expect(response.body).to include("image-thumb-empty", "No image yet")
  end

  it "credits the author and licence of each image" do
    get "/images"

    expect(response.body).to include("Jane", "CC BY-SA 4.0")
  end

  it "breaks the stored images down by licence" do
    create(:breed_image, breed: with_image, license: "CC BY 2.0", source_id: "File:Second.jpg")
    Rails.cache.clear

    get "/images"

    expect(response.body).to include("image-licenses", "CC BY-SA 4.0", "CC BY 2.0")
    expect(response.body).to include("2</strong> licences")
  end

  it "counts coverage" do
    get "/images"

    expect(response.body).to include("50%")
    expect(response.body).to include("With images (1)", "Missing (1)")
  end

  it "filters to breeds that have images" do
    get "/images", params: {filter: "with"}

    expect(response.body).to include("Akita")
    expect(response.body).not_to include("image-thumb-empty")
  end

  it "filters to breeds that are missing images" do
    get "/images", params: {filter: "missing"}

    expect(response.body).to include("Beagle")
    expect(response.body).not_to include(with_image.breed_images.first.url_for(:medium))
  end

  it "falls back to the full list for an unknown filter" do
    get "/images", params: {filter: "bogus"}

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Akita", "Beagle")
  end

  it "is linked from the navigation" do
    get "/"

    expect(response.body).to include('href="/images"')
  end

  it "renders with no breeds at all" do
    BreedImage.find_each(&:destroy)
    Breed.delete_all
    Rails.cache.clear

    get "/images"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("rails images:import_all")
  end
end
