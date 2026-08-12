# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V2::Breeds images" do
  let(:breed) { create(:breed, name: "Akita") }

  def json = JSON.parse(response.body)

  def count_queries
    count = 0
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:cached] || payload[:name].to_s.in?(%w[SCHEMA TRANSACTION])
      count += 1
    end
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  it "serializes every size and the attribution" do
    image = create(:breed_image, breed: breed, author: "Jane", license: "CC BY-SA 4.0")

    get "/api/v2/breeds/#{breed.id}"

    payload = json.dig("data", "attributes", "images").first
    expect(payload["id"]).to eq(image.id)
    expect(payload.values_at("url", "thumb", "medium", "large")).to all(be_present)
    expect(payload["attribution"]).to eq(
      "author" => "Jane",
      "license" => "CC BY-SA 4.0",
      "license_url" => image.license_url,
      "source" => "wikimedia_commons",
      "source_url" => image.page_url
    )
  end

  it "returns an empty list for a breed without images" do
    get "/api/v2/breeds/#{breed.id}"

    expect(json.dig("data", "attributes", "images")).to eq([])
  end

  it "orders images by position" do
    create(:breed_image, breed: breed, position: 2, source_id: "File:B.jpg")
    first = create(:breed_image, breed: breed, position: 1, source_id: "File:A.jpg")

    get "/api/v2/breeds/#{breed.id}"

    expect(json.dig("data", "attributes", "images").first["id"]).to eq(first.id)
  end

  # Imports pre-process the variants, so a request only reads them back.
  def create_image_with_variants(name)
    image = create(:breed_image, breed: create(:breed, name: name))
    BreedImage::VARIANTS.each_key { |variant| image.file.variant(variant).processed }
    image
  end

  it "does not query images once per breed on the index" do
    2.times { |i| create_image_with_variants("Breed #{i}") }
    baseline = count_queries { get "/api/v2/breeds" }

    4.times { |i| create_image_with_variants("Extra #{i}") }

    expect(count_queries { get "/api/v2/breeds" }).to eq(baseline)
  end
end
