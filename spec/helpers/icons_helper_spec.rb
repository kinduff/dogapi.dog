# frozen_string_literal: true

require "rails_helper"

RSpec.describe IconsHelper do
  describe "#icon" do
    it "draws every path of the icon, taking its colour from the text around it" do
      svg = helper.icon(:ruler)

      expect(svg).to include("<svg", %(stroke="currentColor"), %(viewBox="0 0 24 24"))
      expect(svg.scan("<path").size).to eq(described_class::ICONS[:ruler].size)
    end

    it "hides an unlabelled icon from a screen reader" do
      expect(helper.icon(:weight)).to include(%(aria-hidden="true"))
    end

    it "announces a labelled one instead" do
      svg = helper.icon(:mars, label: "Male")

      expect(svg).to include(%(role="img"), %(aria-label="Male"))
      expect(svg).not_to include("aria-hidden")
    end

    it "raises on an icon that does not exist, rather than rendering nothing" do
      expect { helper.icon(:unicorn) }.to raise_error(KeyError)
    end
  end
end
