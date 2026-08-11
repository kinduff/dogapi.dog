# frozen_string_literal: true

# The three jsonb columns defaulted to the JSON *string* `"{}"` rather than an
# empty object, so `Breed.new.life` came back as a String and any store accessor
# write raised `IndexError: string not matched`.
class FixBreedJsonbDefaults < ActiveRecord::Migration[8.1]
  COLUMNS = %i[life male_weight female_weight]

  def up
    COLUMNS.each do |column|
      change_column_default :breeds, column, from: "{}", to: {}
      execute(<<~SQL.squish)
        UPDATE breeds
        SET #{column} = '{}'::jsonb
        WHERE jsonb_typeof(#{column}) <> 'object'
      SQL
    end
  end

  def down
    COLUMNS.each do |column|
      change_column_default :breeds, column, from: {}, to: "{}"
    end
  end
end
