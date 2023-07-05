# frozen_string_literal: true

class GroupSerializer
  include JSONAPI::Serializer

  set_type "group"

  attributes :name
  has_many :breeds
end
