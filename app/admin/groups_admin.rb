# frozen_string_literal: true

Trestle.resource(:groups) do
  menu do
    item :groups, icon: "fa fa-layer-group"
  end

  search do |query|
    if query
      Group.search_by_name(query)
    else
      Group.all
    end
  end

  table do
    column :id, link: true
    column :name
    column :number_of_breeds, ->(group) { group.breeds.count }
  end

  form do |group|
    tab :group do
      text_field :name
    end

    tab :breeds, badge: group.breeds.count do
      table group.breeds, admin: :breeds do
        column :id, link: true
        column :name
        column :created_at
        column :updated_at
        actions
      end
    end
  end
end
