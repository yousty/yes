# frozen_string_literal: true

class CreateTestLocations < ActiveRecord::Migration[7.1]
  def change
    create_table :test_locations, id: :uuid do |t|
      t.integer :revision, null: false, default: -1
      t.timestamps
    end
  end
end
