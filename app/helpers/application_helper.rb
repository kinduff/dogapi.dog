# frozen_string_literal: true

module ApplicationHelper
  def page_title(separator = " - ")
    [content_for(:title), "Dog API by kinduff"].compact.join(separator)
  end

  def page_heading(title)
    content_for(:title) { title }
    content_tag(:h1, title)
  end

  # Share of breeds that have at least one picture, as a number between 0 and
  # 100. Zero breeds counts as zero rather than dividing by nothing.
  def image_coverage(stats)
    return 0.0 if stats[:breeds].to_i.zero?

    100.0 * stats[:covered] / stats[:breeds]
  end

  # One line naming everyone the licence says has to be named, for the tooltip
  # on a thumbnail.
  def image_credit(breed_image)
    [breed_image.author.presence || "Unknown author", breed_image.license, breed_image.source_id].compact.join(" · ")
  end
end
