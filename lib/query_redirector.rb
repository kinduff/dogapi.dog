# frozen_string_literal: true

class QueryRedirector
  def call(_params, request)
    uri = URI.parse(request.original_url)
    if uri.query
      "#{@destination}?#{uri.query}"
    else
      @destination
    end
  end

  def initialize(destination)
    @destination = destination
  end
end
