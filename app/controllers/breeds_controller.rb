# frozen_string_literal: true

# The human facing side of /api/v2/breeds.
class BreedsController < ApplicationController
  include Browsable

  # Mirrors the API's own paging, down to the parameter names, so the page
  # number in the URL is the one in the documented request beside it.
  PER_PAGE = 48
  MAX_PER_PAGE = 200

  STATS_CACHE_KEY = "browse/image_stats"
  STATS_CACHE_TTL = 10.minutes

  def index
    cache_publicly
    @query = params[:q].to_s.strip
    @page = [params.dig(:page, :number).to_i, 1].max
    @per_page = per_page

    scope = @query.present? ? search(breeds_scope) : breeds_scope
    @total = scope.count
    @last_page = [(@total / @per_page.to_f).ceil, 1].max
    @breeds = scope.order(:name).offset((@page - 1) * @per_page).limit(@per_page)
    @groups = Group.order(:name)
    @stats = image_stats
  end

  def show
    @breed = find_breed(params[:id])
    return render_not_found if @breed.nil?

    cache_publicly

    # The rest of the group, as somewhere to go next.
    @siblings = breeds_scope
      .where(group_id: @breed.group_id)
      .where.not(id: @breed.id)
      .order(:name)
      .limit(8)

    @similar_size = similar_size(@breed)
  end

  private

  # Breeds whose weight range overlaps this one, closest midpoint first, from
  # any group but this one (the group already has its own row).
  def similar_size(breed)
    weights = [breed.male_weight_min, breed.male_weight_max, breed.female_weight_min, breed.female_weight_max].compact
    return Breed.none if weights.empty?

    min, max = weights.minmax
    low = "LEAST((male_weight->>'min')::numeric, (female_weight->>'min')::numeric)"
    high = "GREATEST((male_weight->>'max')::numeric, (female_weight->>'max')::numeric)"

    breeds_scope
      .where.not(group_id: breed.group_id)
      .where("#{low} <= ? AND #{high} >= ?", max, min)
      .order(Arel.sql(ActiveRecord::Base.sanitize_sql_array(["ABS((#{low} + #{high}) / 2 - ?), breeds.name", (min + max) / 2.0])))
      .limit(6)
  end

  def per_page
    requested = params.dig(:page, :size).to_i
    return PER_PAGE unless requested.positive?

    requested.clamp(1, MAX_PER_PAGE)
  end

  # Name only, which is all the collection has worth searching.
  def search(scope)
    scope.where("breeds.name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%")
  end

  def image_stats
    Rails.cache.fetch(STATS_CACHE_KEY, expires_in: STATS_CACHE_TTL) do
      total = Breed.count
      covered = Breed.where.associated(:breed_images).distinct.count

      {breeds: total, covered: covered, missing: total - covered, images: BreedImage.count}
    end
  end
end
