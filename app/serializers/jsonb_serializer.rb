# frozen_string_literal: true

class JsonbSerializer
  def self.dump(hash)
    hash.to_json
  end

  def self.load(hash)
    return {} if hash.nil?

    return hash if hash.is_a?(Hash) && hash.empty?

    JSON.parse(hash).with_indifferent_access
  end
end
