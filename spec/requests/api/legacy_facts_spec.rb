# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Legacy /api/facts" do
  before { create_list(:fact, 3) }

  it "is still served by the v1 controller" do
    get "/api/facts"

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include("success" => true)
  end

  it "honours the number parameter" do
    get "/api/facts", params: {number: 2}

    expect(JSON.parse(response.body).fetch("facts").size).to eq(2)
  end
end
