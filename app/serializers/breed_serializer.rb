# frozen_string_literal: true

class BreedSerializer
  include JSONAPI::Serializer

  set_type 'breed'

  attributes :name
  attributes :description
  attributes :life
  attributes :male_weight
  attributes :female_weight
  belongs_to :group
end
