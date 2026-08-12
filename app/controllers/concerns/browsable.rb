# frozen_string_literal: true

# Shared ground for the pages that browse what the API serves.
module Browsable
  extend ActiveSupport::Concern

  SLUG_CACHE_KEY = "browse/slugs"
  SLUG_CACHE_TTL = 1.hour

  # Breed and group data only moves on an import, so these pages can sit in a
  # shared cache for a few minutes. Nothing here is per visitor: there is no
  # sign in, and no form on the site posts anything.
  CACHE_MAX_AGE = 5.minutes
  CACHE_STALE_WHILE_REVALIDATE = 1.hour

  private

  def cache_publicly
    expires_in CACHE_MAX_AGE,
      public: true,
      stale_while_revalidate: CACHE_STALE_WHILE_REVALIDATE
  end

  # A page rather than an empty body: a 404 is somewhere a visitor lands, and
  # a blank one leaves both them and a crawler with nowhere to go.
  def render_not_found
    render "shared/not_found", status: :not_found, formats: :html
  end

  # The whole chain the cards and the galleries touch: the group, the image,
  # its blob, and the variant records the thumbnails are read from. Without it
  # a page of 48 breeds is a few hundred queries.
  def breeds_scope
    Breed.includes(:group, breed_images: {file_attachment: {blob: {variant_records: {image_attachment: :blob}}}})
  end

  # Pages are linked by slug, but the API's own ids have to keep working: they
  # are what a reader copies out of a JSON response.
  def find_breed(id)
    return breeds_scope.find_by(id: id) if uuid?(id)

    breed_id = slugs[:breeds][id.to_s.downcase]
    breed_id && breeds_scope.find_by(id: breed_id)
  end

  def find_group(id)
    return Group.find_by(id: id) if uuid?(id)

    group_id = slugs[:groups][id.to_s.downcase]
    group_id && Group.find_by(id: group_id)
  end

  def uuid?(value)
    value.to_s.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
  end

  # Two small maps rather than a slug column: there are under 300 breeds and
  # nine groups, and neither name changes.
  def slugs
    Rails.cache.fetch(SLUG_CACHE_KEY, expires_in: SLUG_CACHE_TTL) do
      {
        breeds: Breed.pluck(:name, :id).to_h { |name, id| [name.parameterize, id] },
        groups: Group.pluck(:name, :id).to_h { |name, id| [name.parameterize, id] }
      }
    end
  end
end
