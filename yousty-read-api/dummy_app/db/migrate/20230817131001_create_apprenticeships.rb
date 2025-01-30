# frozen_string_literal: true

class CreateApprenticeships < ActiveRecord::Migration[7.0]
  def change
    create_table :apprenticeships, id: :uuid do |t|
      t.uuid :company_id, index: true
      t.boolean :dropout_enabled, default: false

      t.timestamps
    end
  end
end
