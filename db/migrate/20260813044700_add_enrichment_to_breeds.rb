# frozen_string_literal: true

# Room for the attributes an enrichment run fills in. Everything is nullable
# and defaults to empty: a breed nobody has enriched yet answers exactly as it
# does today, and a breed the model had nothing to say about is indistinguishable
# from one it has not seen.
class AddEnrichmentToBreeds < ActiveRecord::Migration[8.1]
  def change
    change_table :breeds, bulk: true do |t|
      # Mirrors the weight columns, in centimetres at the withers.
      t.jsonb :male_height, null: false, default: {}
      t.jsonb :female_height, null: false, default: {}

      # {country, region, era}
      t.jsonb :origin, null: false, default: {}

      # {type, length, colors[]}
      t.jsonb :coat, null: false, default: {}

      # Ratings from 1 to 5, plus exercise_minutes and a temperament list. One
      # column rather than a dozen: they are written and read together, and the
      # set will keep growing.
      t.jsonb :traits, null: false, default: {}

      t.string :other_names, array: true, null: false, default: []
      t.string :recognized_by, array: true, null: false, default: []

      # [{url, title}] — where the enrichment claims it got the facts. Without
      # these none of the above can be checked, so they are part of the payload
      # rather than something kept only in the audit table.
      t.jsonb :sources, null: false, default: []

      t.datetime :enriched_at
      t.string :enrichment_model
    end

    add_index :breeds, :enriched_at

    # Every run is kept, applied or not, so a bad prompt can be traced back to
    # the response that produced it and a breed can be re-reviewed later.
    create_table :breed_enrichments, id: :uuid do |t|
      t.references :breed, null: false, foreign_key: true, type: :uuid
      t.string :model, null: false
      t.string :confidence

      # What the model returned, what survived validation, and why the rest did
      # not.
      t.jsonb :raw_response, null: false, default: {}
      t.jsonb :payload, null: false, default: {}
      t.jsonb :rejections, null: false, default: []

      t.datetime :applied_at

      t.timestamps
    end

    add_index :breed_enrichments, %i[breed_id created_at]
  end
end
