# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Groups pages" do
  let!(:working) { create(:group, name: "Working Group") }
  let!(:toy) { create(:group, name: "Toy Group") }
  let!(:akita) { create(:breed, name: "Akita", group: working) }

  before { Rails.cache.clear }

  describe "GET /groups" do
    it "lists every group with its breed count" do
      get "/groups"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Working Group", "Toy Group", "1 breed")
    end

    it "links each group to its own page" do
      get "/groups"

      expect(response.body).to include('href="/groups/working-group"')
    end

    it "previews the pictures a group has" do
      create(:breed_image, breed: akita)

      get "/groups"

      expect(response.body).to include("dog.webp")
    end

    it "says when a group has no pictures" do
      get "/groups"

      expect(response.body).to include("No pictures imported for this group yet")
    end

    it "shows the API request behind the page" do
      get "/groups"

      expect(response.body).to include("https://dogapi.dog/api/v2/groups", "/docs/api-v2#get-groups")
    end
  end

  describe "GET /groups/:id" do
    it "renders the group by slug" do
      get "/groups/working-group"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Working Group", "Akita")
    end

    it "renders the group by its API id" do
      get "/groups/#{working.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Working Group")
    end

    it "shows only its own breeds" do
      create(:breed, name: "Pug", group: toy)

      get "/groups/working-group"

      expect(response.body).to include("Akita")
      expect(response.body).not_to include('href="/breeds/pug"')
    end

    it "shows the payload the API would return" do
      get "/groups/working-group"

      expect(response.body).to include("https://dogapi.dog/api/v2/groups/#{working.id}")
      expect(response.body).to include("/docs/api-v2#get-groups-id")
    end

    it "404s on an unknown group" do
      get "/groups/not-a-group"

      expect(response).to have_http_status(:not_found)
    end
  end
end
