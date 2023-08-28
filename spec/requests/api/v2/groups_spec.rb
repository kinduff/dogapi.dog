# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "groups", swagger_doc: "v2/swagger.json" do
  path "/groups" do
    get("list groups") do
      tags "Groups"
      response(200, "successful") do
        consumes "application/json"

        example "application/json", :example, {
          data: [
            {
              id: "02124eb6-1baa-410c-90ea-6b8629fb0837",
              type: "group",
              attributes: {
                name: "Foundation Stock Service"
              },
              relationships: {
                breeds: {
                  data: [
                    {
                      id: "b0b6810c-fb88-4987-ad0a-ae0440b04634",
                      type: "breed"
                    },
                    {
                      id: "38e06144-2ac3-43c0-981c-f8598eabc902",
                      type: "breed"
                    }
                  ]
                }
              }
            },
            {
              id: "256db247-70ce-4f08-b6a6-60b27ce369d1",
              type: "group",
              attributes: {
                name: "Herding Group"
              },
              relationships: {
                breeds: {
                  data: [
                    {
                      id: "85d5a702-057f-42e3-a24c-b56e0aa94bf9",
                      type: "breed"
                    }, {
                      id: "eef99f80-266a-4659-a1e7-3af639010984",
                      type: "breed"
                    }
                  ]
                }
              }
            }
          ],
          links: {
            self: "https://dogapi.dog/api/v2/groups",
            current: "https://dogapi.dog/api/v2/groups?page[number]=1",
            next: "https://dogapi.dog/api/v2/groups?page[number]=2",
            last: "https://dogapi.dog/api/v2/groups?page[number]=2"
          }
        }

        run_test!
      end
    end
  end

  path "/groups/{id}" do
    get("get group") do
      response(200, "successful") do
        tags "Groups"
        consumes "application/json"

        parameter name: :id, in: :path, type: :string
        example "application/json", :example, {
          data: {
            id: "02124eb6-1baa-410c-90ea-6b8629fb0837",
            type: "group",
            attributes: {
              name: "Foundation Stock Service"
            },
            relationships: {
              breeds: {
                data: [
                  {
                    id: "b0b6810c-fb88-4987-ad0a-ae0440b04634",
                    type: "breed"
                  },
                  {
                    id: "4bc90a09-5406-4739-96c6-ac2161fbfa4e",
                    type: "breed"
                  }
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
    end

    get("get group with non-existing id") do
      response(404, "not-found") do
        tags "Groups"
        consumes "application/json"

        parameter name: :id, in: :path, type: :string

        let(:id) { 0 }

        run_test!
      end
    end
  end
end
