# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rate limit key" do
  let(:throttle) { Rack::Attack.throttles.fetch("req/ip") }

  def key_for(env)
    throttle.block.call(Rack::Attack::Request.new(Rack::MockRequest.env_for("/api/v2/facts", env)))
  end

  it "uses the connection IP when Cloudflare is not in front" do
    expect(key_for("REMOTE_ADDR" => "203.0.113.9")).to eq("203.0.113.9")
  end

  it "uses the real client behind Cloudflare, not the edge IP" do
    expect(key_for("REMOTE_ADDR" => "172.67.1.1", "HTTP_CF_CONNECTING_IP" => "203.0.113.9")).to eq("203.0.113.9")
  end

  it "ignores an empty Cloudflare header" do
    expect(key_for("REMOTE_ADDR" => "203.0.113.9", "HTTP_CF_CONNECTING_IP" => "")).to eq("203.0.113.9")
  end
end
