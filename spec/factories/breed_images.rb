# frozen_string_literal: true

FactoryBot.define do
  factory :breed_image do
    association :breed
    sequence(:source_id) { |n| "File:Dog_#{n}.jpg" }
    source { "wikimedia_commons" }
    source_url { "https://upload.wikimedia.org/wikipedia/commons/dog.jpg" }
    page_url { "https://commons.wikimedia.org/wiki/File:Dog.jpg" }
    author { "Jane Photographer" }
    license { "CC BY-SA 4.0" }
    license_url { "https://creativecommons.org/licenses/by-sa/4.0/" }

    after(:build) do |breed_image|
      breed_image.file.attach(
        io: Rails.root.join("spec/fixtures/files/dog.jpg").open,
        filename: "dog.jpg",
        content_type: "image/jpeg"
      )
    end
  end
end
