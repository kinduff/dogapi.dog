# frozen_string_literal: true

# The human facing side of /api/v2/groups.
class GroupsController < ApplicationController
  include Browsable

  def index
    cache_publicly
    @groups = Group.order(:name)
    # One row of pictures per group, enough to tell them apart at a glance.
    @previews = preview_images
    @counts = Breed.group(:group_id).count
  end

  def show
    @group = find_group(params[:id])
    return render_not_found if @group.nil?

    cache_publicly

    @breeds = breeds_scope.where(group_id: @group.id).order(:name)
  end

  private

  # The first few images of each group, in one pass rather than a query per
  # group inside the view.
  def preview_images
    BreedImage
      .with_files
      .includes(:breed)
      .joins(:breed)
      .where(position: ..1)
      .order("breeds.name")
      .group_by { |image| image.breed.group_id }
      .transform_values { |images| images.first(6) }
  end
end
