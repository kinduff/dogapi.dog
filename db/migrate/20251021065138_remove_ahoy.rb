class RemoveAhoy < ActiveRecord::Migration[7.0]
  def change
    drop_table :ahoy_events
    drop_table :ahoy_visits
  end
end
