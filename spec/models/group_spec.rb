# frozen_string_literal: true

require "rails_helper"

RSpec.describe Group do
  it { is_expected.to have_many(:breeds) }

  it "collects the breeds that belong to it" do
    group = create(:group)
    breed = create(:breed, group: group)
    create(:breed, group: create(:group))

    expect(group.breeds).to eq([breed])
  end

  it "gets a uuid primary key" do
    expect(create(:group).id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
  end
end
