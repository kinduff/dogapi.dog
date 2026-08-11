# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Facts" do
  describe "GET /api/v1/facts" do
    before { create_list(:fact, 6) }

    def body_facts
      JSON.parse(response.body).fetch("facts")
    end

    it "returns one fact by default" do
      get "/api/v1/facts"

      expect(response).to have_http_status(:ok)
      expect(body_facts.size).to eq(1)
    end

    it "returns the requested number of facts" do
      get "/api/v1/facts", params: {number: 3}

      expect(body_facts.size).to eq(3)
    end

    it "accepts limit as an alias for number" do
      get "/api/v1/facts", params: {limit: 3}

      expect(body_facts.size).to eq(3)
    end

    it "caps the number at 5" do
      get "/api/v1/facts", params: {number: 10}

      expect(response).to have_http_status(:ok)
      expect(body_facts.size).to eq(5)
    end

    it "returns one fact for a negative number" do
      get "/api/v1/facts", params: {number: -1}

      expect(response).to have_http_status(:ok)
      expect(body_facts.size).to eq(1)
    end

    it "returns one fact for a non-numeric number" do
      get "/api/v1/facts", params: {number: "abc"}

      expect(response).to have_http_status(:ok)
      expect(body_facts.size).to eq(1)
    end

    context "with raw=true" do
      it "renders the fact body as plain text" do
        Fact.delete_all
        fact = create(:fact, body: "Dogs have three eyelids.")

        get "/api/v1/facts", params: {raw: "true"}

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/plain")
        expect(response.body).to eq(fact.body)
      end

      it "returns not found when there are no facts" do
        Fact.delete_all

        get "/api/v1/facts", params: {raw: "true"}

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
