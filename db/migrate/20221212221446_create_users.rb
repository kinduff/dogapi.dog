# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :username
      t.string :password_digest
      t.string :remember_token
      t.datetime :remember_token_expires_at

      t.timestamps
    end
  end
end
