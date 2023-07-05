# frozen_string_literal: true

class FactSerializer
  include JSONAPI::Serializer

  set_type "fact"
  set_id :uuid

  attributes :body
end
