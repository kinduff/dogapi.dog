# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API pagination" do
  before { create_list(:breed, 3, group: create(:group)) }

  def json
    JSON.parse(response.body)
  end

  it "returns every breed when no page size is given" do
    get "/api/v2/breeds"

    expect(json["data"].size).to eq(3)
  end

  it "honours page[size]" do
    get "/api/v2/breeds", params: {page: {size: 2}}

    expect(json["data"].size).to eq(2)
  end

  it "falls back to the maximum for a negative page size" do
    get "/api/v2/breeds", params: {page: {size: -1}}

    expect(response).to have_http_status(:ok)
    expect(json["data"].size).to eq(3)
  end

  it "reports pagination in the breeds meta" do
    get "/api/v2/breeds", params: {page: {size: 2}}

    expect(json.dig("meta", "pagination")).to be_present
  end

  it "reports pagination in the groups meta" do
    create_list(:group, 3)

    get "/api/v2/groups", params: {page: {size: 2}}

    expect(json.dig("meta", "pagination")).to be_present
  end
end
