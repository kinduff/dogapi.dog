# frozen_string_literal: true

class PagesController < ApplicationController
  def index
    @fact = Fact.random.first
  end

  def terms
  end

  def docs
  end

  def demo
  end

  def api_v1
    @document = OpenapiDocument.load("v1")
  end

  def api_v2
    @document = OpenapiDocument.load("v2")
  end
end
