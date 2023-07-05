# frozen_string_literal: true

require "rails_helper"

RSpec.describe Group do
  it { is_expected.to have_many(:breeds) }
end
