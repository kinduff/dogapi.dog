# frozen_string_literal: true

require "rails_helper"

RSpec.describe QueryRedirector do
  let(:destination) { "https://example.com/" }
  let(:query_redirector) { described_class.new(destination) }

  describe "#call" do
    context "when there are parameters present" do
      let(:params) { {"foo" => "bar"} }
      let(:request) { double(:request, original_url: "https://example.com/?foo=bar") }

      it "redirects to the correct URL with a query string" do
        expect(query_redirector.call(params, request)).to eq("https://example.com/?foo=bar")
      end
    end

    context "when there are no parameters present" do
      let(:params) { {} }
      let(:request) { double(:request, original_url: "https://example.com/") }

      it "redirects to the correct URL without a query string" do
        expect(query_redirector.call(params, request)).to eq("https://example.com/")
      end
    end
  end

  describe "#initialize" do
    it "sets the destination instance variable" do
      expect(query_redirector.instance_variable_get(:@destination)).to eq(destination)
    end
  end
end
