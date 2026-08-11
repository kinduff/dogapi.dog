# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocsHelper do
  describe "#api_code_lines" do
    it "wraps every line so the viewer can number them" do
      result = helper.api_code_lines("one\ntwo\nthree")

      expect(result.scan('<span class="code-line">').size).to eq(3)
    end

    it "keeps the newlines so the block can still be copied" do
      expect(helper.api_code_lines("one\ntwo")).to include("</span>\n<span")
    end

    it "escapes plain text" do
      result = helper.api_code_lines("<script>alert(1)</script>")

      expect(result).to include("&lt;script&gt;")
      expect(result).not_to include("<script>")
    end

    it "highlights json keys, strings, numbers and constants" do
      result = helper.api_code_lines('{"name": "Akita", "life": 15, "ok": true}', "json")

      expect(result).to include('<span class="nl">"name"</span>')
      expect(result).to include('<span class="s2">"Akita"</span>')
      expect(result).to include('<span class="mi">15</span>')
      expect(result).to include('<span class="kc">true</span>')
    end

    it "highlights javascript keywords" do
      expect(helper.api_code_lines("const body = 1;", "javascript")).to include('<span class="kd">const</span>')
    end

    it "highlights shell arguments" do
      expect(helper.api_code_lines('curl -s "https://dogapi.dog"', "shell")).to include('<span class="nt">-s</span>')
    end

    it "escapes markup inside highlighted code too" do
      result = helper.api_code_lines('{"name": "<img src=x>"}', "json")

      expect(result).to include("&lt;img")
      expect(result).not_to include("<img")
    end

    it "falls back to plain text for an unknown language" do
      expect(helper.api_code_lines("hello", "klingon")).to include('<span class="code-line">hello</span>')
    end
  end
end
