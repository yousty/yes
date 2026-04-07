# frozen_string_literal: true

class CreateJobApps < ActiveRecord::Migration[7.2]
  def change
    create_table(:job_apps, id: :uuid) do |t|
      t.string :name
      t.string :type
      t.datetime :created_at
    end
  end
end
