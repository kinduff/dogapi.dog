# frozen_string_literal: true

module Api
  module V2
    class GroupsController < Api::V2::BaseController
      include JsonapiPaginationDefaults

      before_action :cache_publicly

      def index
        jsonapi_paginate(Group.includes(:breeds).order(:name)) do |paginated|
          render jsonapi: paginated
        end
      end

      def show
        @group = Group.find_by(id: params.fetch(:id))

        if @group.nil?
          head :not_found
        else
          render jsonapi: @group
        end
      end
    end
  end
end
