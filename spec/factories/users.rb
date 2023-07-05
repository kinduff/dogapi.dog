# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { "MyString" }
    password_digest { "MyString" }
    first_name { "MyString" }
    last_name { "MyString" }
    remember_token { "MyString" }
    remember_token_expires_at { "2022-12-12 23:14:46" }
  end
end
