# frozen_string_literal: true

class CreateSharedProfileReadModels < ActiveRecord::Migration[7.1]
  def change
    create_table :shared_profile_read_models, id: :uuid do |t|
      # Fields from PersonalInfo aggregate
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :birth_date

      # Fields from ContactInfo aggregate
      t.string :phone_number
      t.string :address
      t.string :city
      t.string :country
      t.string :postal_code

      # Context-specific revision columns
      t.integer :test_personal_info_revision, null: false, default: -1
      t.integer :test_contact_info_revision, null: false, default: -1
      t.string :locale

      t.timestamps
    end

    add_index :shared_profile_read_models, :email
  end
end
