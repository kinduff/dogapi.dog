# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Breeds pages" do
  let(:group) { create(:group, name: "Working Group") }
  let!(:akita) { create(:breed, name: "Akita", group: group, life: {"min" => 10, "max" => 14}) }
  let!(:beagle) { create(:breed, name: "Beagle", group: group) }

  before { Rails.cache.clear }

  describe "GET /breeds" do
    it "lists the breeds with a link to each one" do
      get "/breeds"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Akita", "Beagle", 'href="/breeds/akita"')
    end

    it "shows a placeholder for a breed without images" do
      get "/breeds"

      expect(response.body).to include("breed-thumb-empty")
    end

    it "shows the picture of a breed that has one" do
      create(:breed_image, breed: akita)

      get "/breeds"

      # Disk URLs are signed and expire, so two built moments apart never match
      # as strings. The rendered filename is the stable part.
      expect(response.body).to include(%(<img class="breed-thumb"), "dog.webp")
    end

    # A card is about 170px wide, and the medium file it used to load is more
    # than twice the bytes of the square thumbnail that fits it. The big one
    # stays available for dense screens.
    it "fills the grid with thumbnails, not the medium files" do
      create(:breed_image, breed: akita)

      get "/breeds"

      # Signed disk URLs carry an expiry, so two of them built moments apart
      # never match as strings. The shape of the srcset is the stable part.
      expect(response.body).to include(" 200w,", " 600w", %(width="200" height="200"))
    end

    it "searches by name" do
      get "/breeds", params: {q: "bea"}

      expect(response.body).to include("Beagle")
      expect(response.body).not_to include('href="/breeds/akita"')
    end

    it "ignores a search that matches nothing, without erroring" do
      get "/breeds", params: {q: "nothing here"}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No breeds here")
    end

    it "treats a search term with wildcards literally" do
      get "/breeds", params: {q: "%"}

      expect(response.body).to include("0 breeds matching")
    end

    it "paginates with the API's own parameter names" do
      get "/breeds", params: {page: {size: 1, number: 2}}

      expect(response.body).to include("Beagle")
      expect(response.body).not_to include('href="/breeds/akita"')
      expect(response.body).to include("Page 2 of 2")
    end

    it "shows the API request behind the page" do
      get "/breeds"

      expect(response.body).to include("https://dogapi.dog/api/v2/breeds?page[number]=1")
      expect(response.body).to include("/docs/api-v2#get-breeds")
    end
  end

  describe "GET /breeds/:id" do
    it "renders the breed by slug" do
      get "/breeds/akita"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Akita", "Working Group", "10–14 years")
    end

    it "shows the researched attributes when a breed has them" do
      akita.update!(
        male_height: {"min" => 66, "max" => 71},
        origin: {"country" => "Japan", "era" => "17th century"},
        coat: {"type" => "double", "length" => "medium", "colors" => %w[red brindle]},
        traits: {"energy" => 4, "temperament" => %w[loyal dignified], "exercise_minutes" => 60},
        other_names: ["Akita Inu"],
        recognized_by: ["AKC"],
        sources: [{"url" => "https://www.akc.org/dog-breeds/akita/", "title" => "AKC"}]
      )

      get "/breeds/akita"

      expect(response.body).to include(
        "66–71 cm",
        "Japan (17th century)",
        "medium double",
        "loyal and dignified",
        "60 minutes a day",
        "Akita Inu",
        "AKC"
      )
    end

    it "leaves the researched rows out for a breed nobody has enriched" do
      get "/breeds/beagle"

      expect(response.body).not_to include("Origin", "Traits")
    end

    it "renders the breed by its API id" do
      get "/breeds/#{akita.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Akita")
    end

    it "shows every image with its credit" do
      create(:breed_image, breed: akita, author: "Jane", license: "CC BY-SA 4.0")

      get "/breeds/akita"

      expect(response.body).to include("Jane", "CC BY-SA 4.0")
    end

    it "makes every image a gallery thumbnail" do
      create(:breed_image, breed: akita, source_id: "File:One.jpg")
      second = create(:breed_image, breed: akita, source_id: "File:Two.jpg")
      second.file.attach(
        io: Rails.root.join("spec/fixtures/files/dog_alt.jpg").open,
        filename: "other.jpg",
        content_type: "image/jpeg"
      )

      get "/breeds/akita"

      expect(response.body.scan("data-gallery-item").size).to eq(2)
      expect(response.body).to include("data-gallery-hero", "breed_gallery")
    end

    it "carries a caption per image, with only the first one showing" do
      create(:breed_image, breed: akita, source_id: "File:One.jpg", author: "Jane")
      create(:breed_image, breed: akita, source_id: "File:Two.jpg", author: "Sam")

      get "/breeds/akita"

      expect(response.body.scan("data-gallery-credit").size).to eq(2)
      expect(response.body).to include("Jane", "Sam")
    end

    it "leaves the pictures as plain links for a reader without javascript" do
      create(:breed_image, breed: akita)

      get "/breeds/akita"

      # Signed disk URLs differ every time they are built, so the filename is
      # the part worth asserting on.
      expect(response.body).to match(%r{<a href="[^"]*dog\.jpg"[^>]*data-gallery-link})
    end

    it "says so when there is no picture" do
      get "/breeds/akita"

      expect(response.body).to include("No picture for this breed yet")
    end

    it "links to the rest of the group" do
      get "/breeds/akita"

      expect(response.body).to include("More from the Working Group", 'href="/breeds/beagle"')
    end

    it "shows the payload the API would return" do
      get "/breeds/akita"

      expect(response.body).to include("https://dogapi.dog/api/v2/breeds/#{akita.id}")
      expect(response.body).to include("/docs/api-v2#get-breeds-id")
      expect(response.body).to include("hypoallergenic")
    end

    it "points at the image endpoint" do
      get "/breeds/akita"

      expect(response.body).to include("/breeds/#{akita.id}/image")
    end

    it "404s on an unknown slug" do
      get "/breeds/not-a-breed"

      expect(response).to have_http_status(:not_found)
    end

    it "404s on an unknown id" do
      get "/breeds/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "query counts" do
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

    def breed_with_processed_image(name)
      breed = create(:breed, name: name, group: group)
      image = create(:breed_image, breed: breed)
      BreedImage::VARIANTS.each_key { |variant| image.file.variant(variant).processed }
      breed
    end

    it "does not grow with the number of breeds on the page" do
      2.times { |i| breed_with_processed_image("Extra #{i}") }
      Rails.cache.clear
      baseline = count_queries { get "/breeds" }

      4.times { |i| breed_with_processed_image("More #{i}") }
      Rails.cache.clear

      expect(count_queries { get "/breeds" }).to eq(baseline)
    end
  end

  describe "retired pages" do
    it "sends the old demo page to the breeds" do
      get "/demo"

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/breeds")
    end

    it "sends the old images gallery to the breeds" do
      get "/images"

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/breeds")
    end
  end
end
