# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreedImageImportJob do
  include ActiveJob::TestHelper

  let(:breed) { create(:breed, name: "Akita") }

  def stub_import(imported: [], errors: [])
    result = BreedImages::Importer::Result.new(imported: imported, skipped: [], errors: errors)
    allow(BreedImages::Importer).to receive(:call).and_return(result)
  end

  it "imports the breed from the source it was given" do
    stub_import

    described_class.perform_now(breed.id, "wikipedia_lead", 3)

    expect(BreedImages::Importer).to have_received(:call)
      .with(breed, source: "wikipedia_lead", limit: 3)
  end

  it "queues a review for each image it imported" do
    image = create(:breed_image, breed: breed)
    stub_import(imported: [image])

    expect { described_class.perform_now(breed.id, "wikipedia_lead", 3) }
      .to have_enqueued_job(BreedImageReviewJob).with(image.id)
  end

  it "hands the breed to the next source when it is still short" do
    stub_import

    expect { described_class.perform_now(breed.id, "wikipedia_lead", 3) }
      .to have_enqueued_job(described_class).with(breed.id, "wikipedia_article", 3, review: true)
  end

  it "stops once the breed has enough pictures" do
    create_list(:breed_image, 3, breed: breed)
    stub_import

    expect { described_class.perform_now(breed.id, "wikipedia_lead", 3) }
      .not_to have_enqueued_job(described_class)
  end

  it "stops at the end of the list of sources" do
    stub_import

    expect { described_class.perform_now(breed.id, BreedImages::SOURCE_ORDER.last, 3) }
      .not_to have_enqueued_job(described_class)
  end

  it "does nothing for a breed that has since been deleted" do
    expect { described_class.perform_now(SecureRandom.uuid, "wikipedia_lead", 3) }.not_to raise_error
  end
end
