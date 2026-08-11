# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health check" do
  it "answers on /up" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
