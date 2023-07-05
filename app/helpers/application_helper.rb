# frozen_string_literal: true

module ApplicationHelper
  def page_title(separator = " - ")
    [content_for(:title), "Dog API by kinduff"].compact.join(separator)
  end

  def page_heading(title)
    content_for(:title) { title }
    content_tag(:h1, title)
  end
end
