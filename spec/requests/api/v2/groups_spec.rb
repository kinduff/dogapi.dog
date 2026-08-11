# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "groups", swagger_doc: "v2/swagger.json" do
  path "/groups" do
    get("list groups") do
      tags "Groups"
      description <<~TEXT.strip
        Returns every breed group, ordered by name and split into pages.

        Pages hold up to 1000 records, and there are only about 20 groups, so a
        plain request returns all of them. Each group lists the breeds that
        belong to it.

        Responses may be cached publicly for up to 5 minutes.
      TEXT
      produces "application/json"

      parameter name: "page[number]", in: :query, required: false,
        schema: {type: :integer, minimum: 1},
        description: "Page number for pagination"
      parameter name: "page[size]", in: :query, required: false,
        schema: {type: :integer, minimum: 1, maximum: 1000},
        description: "Number of records per page (max 1000)"

      response(200, "successful") do
        schema "$ref": "#/components/schemas/GroupCollection"

        example "application/json", :example, {
          data: [
            {
              id: "02124eb6-1baa-410c-90ea-6b8629fb0837",
              type: "group",
              attributes: {name: "Foundation Stock Service"},
              relationships: {
                breeds: {
                  data: [
                    {id: "b0b6810c-fb88-4987-ad0a-ae0440b04634", type: "breed"},
                    {id: "38e06144-2ac3-43c0-981c-f8598eabc902", type: "breed"}
                  ]
                }
              }
            },
            {
              id: "256db247-70ce-4f08-b6a6-60b27ce369d1",
              type: "group",
              attributes: {name: "Herding Group"},
              relationships: {
                breeds: {
                  data: [
                    {id: "85d5a702-057f-42e3-a24c-b56e0aa94bf9", type: "breed"},
                    {id: "eef99f80-266a-4659-a1e7-3af639010984", type: "breed"}
                  ]
                }
              }
            }
          ],
          meta: {
            pagination: {current: 1, records: 20}
          },
          links: {
            self: "https://dogapi.dog/api/v2/groups",
            current: "https://dogapi.dog/api/v2/groups?page[number]=1"
          }
        }

        run_test!
      end
    end
  end

  path "/groups/{id}" do
    get("get group") do
      tags "Groups"
      description "Returns a single group. Unknown and malformed ids both return 404."
      produces "application/json"

      parameter name: :id, in: :path, required: true,
        schema: {type: :string, format: :uuid},
        description: "Group id"

      response(200, "successful") do
        schema "$ref": "#/components/schemas/GroupResource"

        example "application/json", :example, {
          data: {
            id: "02124eb6-1baa-410c-90ea-6b8629fb0837",
            type: "group",
            attributes: {name: "Foundation Stock Service"},
            relationships: {
              breeds: {
                data: [
                  {id: "b0b6810c-fb88-4987-ad0a-ae0440b04634", type: "breed"},
                  {id: "4bc90a09-5406-4739-96c6-ac2161fbfa4e", type: "breed"}
                ]
              }
            }
          },
          links: {
            self: "https://dogapi.dog/api/v2/groups/02124eb6-1baa-410c-90ea-6b8629fb0837"
          }
        }

        let(:id) { create(:group).id }

        run_test!
      end

      response(404, "no group with that id") do
        let(:id) { SecureRandom.uuid }

        run_test!
      end
    end
  end
end
