# frozen_string_literal: true

# The table was created in 2022 for an authentication feature that was never
# built: no routes, no controllers, and no `has_secure_password` ever existed.
class DropUsers < ActiveRecord::Migration[8.1]
  def change
    drop_table :users do |t|
      t.string :username
      t.string :password_digest
      t.string :remember_token
      t.datetime :remember_token_expires_at

      t.timestamps
    end
  end
end
