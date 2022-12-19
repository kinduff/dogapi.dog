# frozen_string_literal: true

Trestle.resource(:account, model: User, scope: Auth, singular: true) do
  instance do
    current_user
  end

  remove_action :new, :edit, :destroy

  form do |_user|
    text_field :username

    row do
      col(sm: 6) { password_field :password }
      col(sm: 6) { password_field :password_confirmation }
    end
  end

  # Limit the parameters that are permitted to be updated by the user
  params do |params|
    params.require(:account).permit(:username, :password, :password_confirmation)
  end
end
