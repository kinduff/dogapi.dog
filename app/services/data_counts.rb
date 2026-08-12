# frozen_string_literal: true

# What the API holds right now. Counting four small tables once an hour is
# cheaper than keeping the numbers in the copy, where they go stale.
class DataCounts
  CACHE_KEY = "data/counts"
  CACHE_TTL = 1.hour

  def self.call
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
      {breeds: Breed.count, groups: Group.count, facts: Fact.count, images: BreedImage.count}
    end
  end
end
