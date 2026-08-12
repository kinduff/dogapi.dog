# frozen_string_literal: true

module Api
  module V2
    class GroupsController < Api::V2::BaseController
      include JsonapiPaginationDefaults

      before_action :cache_publicly

      def index
        jsonapi_paginate(groups.order(:name)) do |paginated|
          render jsonapi: paginated
        end
      end

      def show
        @group = groups.find_by(id: params.fetch(:id))

        if @group.nil?
          head :not_found
        else
          render jsonapi: @group
        end
      end

      private

      # `?include=breeds` renders full breeds, images and all, so the same
      # preloading the breeds endpoint needs applies here.
      def groups
        Group.includes(breeds: [:group, {breed_images: {file_attachment: {blob: {variant_records: {image_attachment: :blob}}}}}])
      end
    end
  end
end
