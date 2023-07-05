# frozen_string_literal: true

Trestle.resource(:facts) do
  menu do
    item :facts, icon: "fa fa-star", priority: :first
  end

  search do |query|
    if query
      Fact.search_by_body(query)
    else
      Fact.all
    end
  end

  table do
    column :uuid, link: true
    column :body
    column :created_at
    column :updated_at
    actions
  end

  form do |_fact|
    text_field :uuid, label: "UUID", readonly: true
    text_area :body
  end
end
