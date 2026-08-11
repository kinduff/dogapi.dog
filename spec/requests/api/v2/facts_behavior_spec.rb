# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V2::Facts" do
  describe "GET /api/v2/facts" do
    before { create_list(:fact, 6) }

    def body_data
      JSON.parse(response.body).fetch("data")
    end

    it "returns one fact by default" do
      get "/api/v2/facts"

      expect(response).to have_http_status(:ok)
      expect(body_data.size).to eq(1)
    end

    it "returns the requested number of facts" do
      get "/api/v2/facts", params: {limit: 3}

      expect(body_data.size).to eq(3)
    end

    it "caps the limit at 5" do
      get "/api/v2/facts", params: {limit: 10}

      expect(response).to have_http_status(:ok)
      expect(body_data.size).to eq(5)
    end

    it "returns one fact for a negative limit" do
      get "/api/v2/facts", params: {limit: -1}

      expect(response).to have_http_status(:ok)
      expect(body_data.size).to eq(1)
    end

    it "returns one fact for a non-numeric limit" do
      get "/api/v2/facts", params: {limit: "abc"}

      expect(response).to have_http_status(:ok)
      expect(body_data.size).to eq(1)
    end

    it "returns an empty collection when there are no facts" do
      Fact.delete_all

      get "/api/v2/facts"

      expect(response).to have_http_status(:ok)
      expect(body_data).to eq([])
    end
  end
end
