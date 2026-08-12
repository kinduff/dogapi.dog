# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImages::Reviewer do
  subject(:review) { described_class.call(breed_image, model: "claude-opus-5", client: client) }

  let(:breed) { create(:breed, name: "Akita") }
  let(:breed_image) { create(:breed_image, breed: breed) }
  let(:client) { Anthropic::Client.new(api_key: "test-key", max_retries: 0) }

  def attributes(score: 8, notes: "One adult dog, sharp, plain background.", **overrides)
    {
      "score" => score,
      "shows_a_dog" => true,
      "is_collage" => false,
      "single_dog" => true,
      "whole_dog_visible" => true,
      "sharp" => true,
      "plausible_breed" => true,
      "has_people" => false,
      "has_text_or_watermark" => false,
      "is_photograph" => true,
      "is_puppy" => false,
      "notes" => notes
    }.merge(overrides.transform_keys(&:to_s))
  end

  def stub_review(body)
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(
      status: 200,
      body: body.to_json,
      headers: {"Content-Type" => "application/json"}
    )
  end

  def message(text:, stop_reason: "end_turn")
    {
      id: "msg_1",
      type: "message",
      role: "assistant",
      model: "claude-opus-5",
      content: [{type: "text", text: text}],
      stop_reason: stop_reason,
      usage: {input_tokens: 900, output_tokens: 40}
    }
  end

  it "returns the score and the sentence explaining it" do
    stub_review(message(text: attributes.to_json))

    expect(review).to have_attributes(score: 8, notes: "One adult dog, sharp, plain background.")
    expect(review).to be_good_enough
  end

  it "keeps the whole judgement, not just the score" do
    stub_review(message(text: attributes.to_json))

    expect(review.attributes).to include("single_dog" => true, "is_puppy" => false)
    expect(review.usage).to include(input_tokens: 900)
  end

  it "calls a low score a rejection" do
    stub_review(message(text: attributes(score: 3, notes: "Three dogs at a show.").to_json))

    expect(review).to be_rejected
  end

  it "scores a picture with no dog in it at zero, whatever it was given" do
    stub_review(message(text: attributes(score: 3, shows_a_dog: false, notes: "An empty kennel.").to_json))

    expect(review.score).to eq(0)
    expect(review).to be_unusable
  end

  it "scores a grid of several pictures at zero" do
    stub_review(message(text: attributes(score: 5, is_collage: true, notes: "Four dogs in a grid.").to_json))

    expect(review.score).to eq(0)
    expect(review).to be_unusable
  end

  it "leaves a picture that is merely poor where the model put it" do
    stub_review(message(text: attributes(score: 3, notes: "Blurred, shot from above.").to_json))

    expect(review.score).to eq(3)
    expect(review).not_to be_unusable
  end

  it "sends the picture alongside the breed it claims to show" do
    stub_review(message(text: attributes.to_json))

    review

    expect(a_request(:post, "https://api.anthropic.com/v1/messages").with { |request|
      body = JSON.parse(request.body)
      content = body.dig("messages", 0, "content")

      content.first["type"] == "image" &&
        content.first.dig("source", "media_type") == "image/webp" &&
        content.first.dig("source", "data").present? &&
        content.last["text"].include?("Akita")
    }).to have_been_made
  end

  it "caches the rubric, which is the same for every picture in a run" do
    stub_review(message(text: attributes.to_json))

    review

    expect(a_request(:post, "https://api.anthropic.com/v1/messages").with { |request|
      JSON.parse(request.body).dig("system", 0, "cache_control", "type") == "ephemeral"
    }).to have_been_made
  end

  it "raises when the model answers with something that is not the agreed shape" do
    stub_review(message(text: "not json"))

    expect { review }.to raise_error(BreedImages::Error, /unexpected token|expected object/i)
  end

  it "raises when the model refuses" do
    stub_review(message(text: "", stop_reason: "refusal"))

    expect { review }.to raise_error(BreedImages::Error, /refused/)
  end

  it "raises when the picture has no file to look at" do
    image = build(:breed_image, breed: breed)
    image.file.detach

    expect { described_class.call(image, model: "claude-opus-5", client: client) }
      .to raise_error(BreedImages::Error, /no file attached/)
  end

  it "raises when the API is unavailable" do
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(status: 529, body: "{}")

    expect { review }.to raise_error(BreedImages::Error)
  end
end
