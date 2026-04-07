# frozen_string_literal: true

class CreateApprenticeships < ActiveRecord::Migration[7.2]
  def change
    create_table(:apprenticeships, id: :uuid) do |t|
      t.string :name
      t.uuid :company_id
      t.datetime :created_at
    end
  end
end
