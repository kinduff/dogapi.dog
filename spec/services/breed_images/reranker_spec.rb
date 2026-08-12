# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImages::Reranker do
  subject(:result) { described_class.call(breed, force: force, model: "claude-opus-5", client: client) }

  let(:breed) { create(:breed, name: "Akita") }
  let(:client) { instance_double(Anthropic::Client) }
  let(:force) { false }

  def image(position:, **attributes)
    create(:breed_image, breed: breed, position: position, **attributes)
  end

  # The reviewer is what talks to the model; what this cares about is the score
  # it comes back with and where the picture ends up because of it.
  def stub_reviews(scores)
    allow(BreedImages::Reviewer).to receive(:call) do |breed_image, **|
      score = scores.fetch(breed_image.source_id)

      BreedImages::Reviewer::Result.new(score: score, notes: "#{score}/10", attributes: {}, usage: {})
    end
  end

  it "puts the best picture first" do
    worst = image(position: 1, source_id: "File:Worst.jpg")
    best = image(position: 2, source_id: "File:Best.jpg")
    stub_reviews("File:Worst.jpg" => 4, "File:Best.jpg" => 9)

    result

    expect(breed.breed_images.reload.map(&:source_id)).to eq(["File:Best.jpg", "File:Worst.jpg"])
    expect(best.reload.position).to be < worst.reload.position
    expect(breed.reload.primary_image.source_id).to eq("File:Best.jpg")
  end

  it "records the score and the reason with the picture" do
    image(position: 1, source_id: "File:One.jpg")
    stub_reviews("File:One.jpg" => 7)

    result

    expect(breed.breed_images.first).to have_attributes(score: 7, review_notes: "7/10")
    expect(breed.breed_images.first.reviewed_at).to be_present
  end

  it "leaves a picture that has already been judged alone" do
    image(position: 1, source_id: "File:Judged.jpg", score: 9, reviewed_at: 1.day.ago)
    image(position: 2, source_id: "File:New.jpg")
    stub_reviews("File:New.jpg" => 3)

    expect(result.reviewed.map(&:source_id)).to eq(["File:New.jpg"])
    expect(result.skipped.map(&:source_id)).to eq(["File:Judged.jpg"])
  end

  context "when forced" do
    let(:force) { true }

    it "judges everything again" do
      image(position: 1, source_id: "File:Judged.jpg", score: 9, reviewed_at: 1.day.ago)
      stub_reviews("File:Judged.jpg" => 2)

      expect(result.reviewed.size).to eq(1)
      expect(breed.breed_images.first.score).to eq(2)
    end
  end

  it "keeps a picture nobody could judge behind the ones that were" do
    image(position: 1, source_id: "File:Broken.jpg")
    image(position: 2, source_id: "File:Fine.jpg")
    allow(BreedImages::Reviewer).to receive(:call) do |breed_image, **|
      raise BreedImages::Error, "boom" if breed_image.source_id == "File:Broken.jpg"

      BreedImages::Reviewer::Result.new(score: 5, notes: "fine", attributes: {}, usage: {})
    end

    expect(result.errors.join).to include("boom")
    expect(breed.breed_images.reload.map(&:source_id)).to eq(["File:Fine.jpg", "File:Broken.jpg"])
  end

  it "orders equal scores by the order they were imported in" do
    image(position: 1, source_id: "File:First.jpg")
    image(position: 2, source_id: "File:Second.jpg")
    stub_reviews("File:First.jpg" => 6, "File:Second.jpg" => 6)

    result

    expect(breed.breed_images.reload.map(&:source_id)).to eq(["File:First.jpg", "File:Second.jpg"])
  end

  it "reports the score of the picture it settled on" do
    image(position: 1, source_id: "File:One.jpg")
    stub_reviews("File:One.jpg" => 8)

    expect(result.summary).to eq("1 reviewed, 0 skipped, 0 failed, best 8/10")
  end

  it "asks nothing of the model for a breed with no pictures" do
    allow(BreedImages::Reviewer).to receive(:call)

    expect(result.reviewed).to be_empty
    expect(BreedImages::Reviewer).not_to have_received(:call)
  end
end
