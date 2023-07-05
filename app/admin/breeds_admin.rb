# frozen_string_literal: true

Trestle.resource(:breeds) do
  menu do
    item :breeds, icon: "fa fa-dog"
  end

  search do |query|
    if query
      Breed.search_by_name(query)
    else
      Breed.all
    end
  end

  active_storage_fields do
    [:images]
  end

  form do |_breed|
    text_field :name
    collection_select :group_id, Group.all, :id, :name
    text_area :description
    number_field :life_min
    number_field :life_max
    number_field :male_weight_min
    number_field :male_weight_max
    number_field :female_weight_min
    number_field :female_weight_max
    check_box :hypoallergenic
    active_storage_field :images
  end
end
