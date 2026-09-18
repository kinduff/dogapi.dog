# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V2::Groups query counts" do
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

  # GroupSerializer renders a `breeds` relationship, so the index has to preload
  # them. Without it the query count grows with the number of groups.
  it "does not query breeds once per group" do
    3.times { create_list(:breed, 2, group: create(:group)) }
    baseline = count_queries { get "/api/v2/groups" }

    6.times { create_list(:breed, 2, group: create(:group)) }

    expect(count_queries { get "/api/v2/groups" }).to eq(baseline)
  end

  # Images are only rendered under `?include=breeds`, so the plain index must
  # not pay for loading them.
  it "does not load images unless breeds are included" do
    create(:breed_image)
    tables = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      tables << payload[:sql][/FROM "(\w+)"/, 1]
    end

    get "/api/v2/groups"
    expect(tables.compact).not_to include(a_string_starting_with("active_storage"), "breed_images")

    tables.clear
    get "/api/v2/groups?include=breeds"
    expect(tables.compact).to include("breed_images", "active_storage_blobs")
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end
end
