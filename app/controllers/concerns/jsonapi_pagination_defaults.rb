# frozen_string_literal: true

# Shared pagination behaviour for the paginated v2 collections.
module JsonapiPaginationDefaults
  extend ActiveSupport::Concern

  MAX_PAGE_SIZE = 1000

  included do
    include JSONAPI::Pagination
  end

  private

  # An unset, zero, negative or oversized `page[size]` all fall back to the
  # maximum, which is what this API has always returned by default.
  def jsonapi_page_size(pagination_params)
    per_page = pagination_params[:size].to_f.to_i
    return MAX_PAGE_SIZE if per_page < 1 || per_page > MAX_PAGE_SIZE

    per_page
  end

  def jsonapi_meta(resources)
    pagination = jsonapi_pagination_meta(resources)

    {pagination: pagination} if pagination.present?
  end
end
