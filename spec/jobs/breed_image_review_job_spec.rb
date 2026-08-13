# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImageReviewJob do
  let(:breed) { create(:breed, name: "Akita") }

  def review(score)
    BreedImages::Reviewer::Result.new(score: score, notes: "#{score}/10", attributes: {}, usage: {})
  end

  it "stores what the reviewer said" do
    image = create(:breed_image, breed: breed)
    allow(BreedImages::Reviewer).to receive(:call).and_return(review(7))

    described_class.perform_now(image.id)

    expect(image.reload).to have_attributes(score: 7, review_notes: "7/10")
    expect(image.reviewed_at).to be_present
  end

  it "leaves a picture that has already been judged alone" do
    image = create(:breed_image, breed: breed, score: 9, reviewed_at: 1.day.ago)
    allow(BreedImages::Reviewer).to receive(:call)

    described_class.perform_now(image.id)

    expect(BreedImages::Reviewer).not_to have_received(:call)
  end

  it "judges it again when forced" do
    image = create(:breed_image, breed: breed, score: 9, reviewed_at: 1.day.ago)
    allow(BreedImages::Reviewer).to receive(:call).and_return(review(2))

    described_class.perform_now(image.id, force: true)

    expect(image.reload.score).to eq(2)
  end

  it "waits for the breed's last picture before reordering" do
    first = create(:breed_image, breed: breed, position: 1, source_id: "File:First.jpg")
    create(:breed_image, breed: breed, position: 2, source_id: "File:Second.jpg")
    allow(BreedImages::Reviewer).to receive(:call).and_return(review(1))

    described_class.perform_now(first.id)

    expect(first.reload.position).to eq(1)
  end

  it "reorders once the last picture has been scored" do
    worst = create(:breed_image, breed: breed, position: 1, source_id: "File:Worst.jpg")
    best = create(:breed_image, breed: breed, position: 2, source_id: "File:Best.jpg")
    allow(BreedImages::Reviewer).to receive(:call) do |image|
      review((image.source_id == "File:Best.jpg") ? 9 : 3)
    end

    described_class.perform_now(worst.id)
    described_class.perform_now(best.id)

    expect(breed.reload.primary_image.source_id).to eq("File:Best.jpg")
  end

  it "does nothing for a picture that has since been deleted" do
    expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
  end
end
