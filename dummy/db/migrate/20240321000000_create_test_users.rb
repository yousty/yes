# frozen_string_literal: true

class CreateTestUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :test_users, id: :uuid do |t|
      t.string :email
      t.string :name
      t.integer :age
      t.boolean :active
      t.string :document_ids
      t.string :another
      t.string :test_field # dynamically generated in specs
      t.uuid :location_id # dynamically generated in specs

      t.string :shortcut_description
      t.integer :shortcuts_used
      t.boolean :shortcut_usage_enabled
      t.boolean :shortcut_toggle
      t.boolean :published
      t.string :locale_test
      t.string :default_payload_test
      t.datetime :dynamic_default_test

      t.integer :revision, null: false, default: -1

      t.timestamps
    end
  end
end
