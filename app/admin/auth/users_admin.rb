# frozen_string_literal: true

Trestle.resource(:users, model: User, scope: Auth) do
  menu do
    group :configuration, priority: :last do
      item :users, icon: "fas fa-users"
    end
  end

  table do
    column :username, link: true
    actions do |a|
      a.delete unless a.instance == current_user
    end
  end

  form do |_user|
    text_field :username

    row do
      col(sm: 6) { password_field :password }
      col(sm: 6) { password_field :password_confirmation }
    end
  end
end
