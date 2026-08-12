# frozen_string_literal: true

class BreedSerializer
  include JSONAPI::Serializer

  set_type "breed"

  attributes :name
  attributes :description
  attributes :life
  attributes :male_weight
  attributes :female_weight
  attributes :hypoallergenic

  # Filled in by an enrichment run rather than by hand, so a breed nobody has
  # researched yet answers with empty values rather than with nulls the client
  # has to special case.
  attributes :male_height
  attributes :female_height
  attributes :origin
  attributes :coat
  attributes :traits
  attributes :other_names
  attributes :recognized_by
  attributes :sources

  # Every image carries the credit its licence demands, so a client can display
  # the picture and the attribution together without a second request.
  attribute :images do |breed|
    breed.breed_images.map do |image|
      {
        id: image.id,
        url: image.url_for,
        thumb: image.url_for(:thumb),
        medium: image.url_for(:medium),
        large: image.url_for(:large),
        attribution: image.attribution
      }
    end
  end

  belongs_to :group
end
