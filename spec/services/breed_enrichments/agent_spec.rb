# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedEnrichments::Agent do
  subject(:result) { described_class.call(breed, model: "claude-sonnet-5", client: client) }

  let(:client) { Anthropic::Client.new(api_key: "test-key", max_retries: 0) }

  let(:breed) { create(:breed, name: "Akita") }
  let(:answer) do
    {
      "name" => "Akita",
      "male_height" => {"min" => 66, "max" => 71},
      "sources" => [{"url" => "https://www.akc.org/dog-breeds/akita/"}],
      "confidence" => "high"
    }
  end

  # The API replies with the object as text, after the search blocks the tool
  # produced along the way.
  def stub_message(content:, stop_reason: "end_turn")
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
      status: 200,
      headers: {"Content-Type" => "application/json"},
      body: {
        id: "msg_1",
        type: "message",
        role: "assistant",
        model: "claude-sonnet-5",
        content: content,
        stop_reason: stop_reason,
        usage: {input_tokens: 100, output_tokens: 50}
      }.to_json
    )
  end

  it "returns the parsed object" do
    stub_message(content: [{type: "text", text: answer.to_json}])

    expect(result.attributes).to eq(answer)
    expect(result.confidence).to eq("high")
    expect(result.usage[:output_tokens]).to eq(50)
  end

  it "asks the model to search, in the shape the schema describes" do
    stub_message(content: [{type: "text", text: answer.to_json}])
    result

    expect(a_request(:post, "https://api.anthropic.com/v1/messages").with { |request|
      body = JSON.parse(request.body)

      body["model"] == "claude-sonnet-5" &&
        body["tools"].first["type"] == "web_search_20260209" &&
        body["output_config"]["format"]["type"] == "json_schema" &&
        body["output_config"]["format"]["schema"]["required"] == %w[name sources confidence] &&
        body["system"].first["cache_control"] == {"type" => "ephemeral"} &&
        body["messages"].first["content"].include?("Akita")
    }).to have_been_made
  end

  it "ignores the search blocks that come back with the answer" do
    stub_message(content: [
      {type: "server_tool_use", id: "srvtoolu_1", name: "web_search", input: {query: "akita"}},
      {type: "text", text: answer.to_json}
    ])

    expect(result.attributes["name"]).to eq("Akita")
  end

  it "raises when the answer is not the object" do
    stub_message(content: [{type: "text", text: "Sorry, I could not find anything."}])

    expect { result }.to raise_error(BreedEnrichments::Error, /Akita/)
  end

  it "raises when the response carries no text at all" do
    stub_message(content: [], stop_reason: "max_tokens")

    expect { result }.to raise_error(BreedEnrichments::Error, /no text/)
  end

  it "raises rather than retrying when the API rejects the request" do
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
      status: 400,
      headers: {"Content-Type" => "application/json"},
      body: {type: "error", error: {type: "invalid_request_error", message: "bad"}}.to_json
    )

    expect { result }.to raise_error(BreedEnrichments::Error, /claude-sonnet-5/)
  end
end
