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
end
