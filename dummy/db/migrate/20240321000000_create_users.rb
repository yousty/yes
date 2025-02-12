# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :email
      t.string :name
      t.integer :age
      t.boolean :active
      t.string :test_field # dynamically generated in specs
      t.uuid :location_id # dynamically generated in specs
      t.integer :revision, null: false, default: -1

      t.timestamps
    end
  end
end
