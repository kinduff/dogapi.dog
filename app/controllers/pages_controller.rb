# frozen_string_literal: true

class PagesController < ApplicationController
  def index
    @fact = Fact.order("RANDOM()").first
  end

  def terms
  end

  def stats
  end

  def docs
  end

  def api_v1
  end

  def api_v2
  end
end
