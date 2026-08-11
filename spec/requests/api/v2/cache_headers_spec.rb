# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API cache headers" do
  let(:group) { create(:group) }
  let(:breed) { create(:breed, group: group) }

  it "lets shared caches store the breeds index" do
    breed

    get "/api/v2/breeds"

    expect(response.headers["Cache-Control"]).to include("public", "max-age=300")
  end

  it "lets shared caches store a single breed" do
    get "/api/v2/breeds/#{breed.id}"

    expect(response.headers["Cache-Control"]).to include("public")
  end

  it "lets shared caches store the groups index" do
    group

    get "/api/v2/groups"

    expect(response.headers["Cache-Control"]).to include("public", "max-age=300")
  end

  it "sends an etag so clients can revalidate" do
    breed

    get "/api/v2/breeds"

    expect(response.headers["ETag"]).to be_present
  end

  it "answers with 304 when the etag still matches" do
    breed
    get "/api/v2/breeds"

    get "/api/v2/breeds", headers: {"If-None-Match" => response.headers["ETag"]}

    expect(response).to have_http_status(:not_modified)
  end

  it "never stores random fact responses" do
    create(:fact)

    get "/api/v2/facts"

    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "never stores random v1 fact responses" do
    create(:fact)

    get "/api/v1/facts"

    expect(response.headers["Cache-Control"]).to include("no-store")
  end
end
