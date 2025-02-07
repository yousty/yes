# frozen_string_literal: true

class CreateLocations < ActiveRecord::Migration[7.1]
  def change
    create_table :locations, id: :uuid do |t|
      t.integer :revision, null: false, default: 0
      t.timestamps
    end
  end
end
