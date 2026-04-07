class CreatePersistedFilters < ActiveRecord::Migration[7.2]
  def change
    create_table :persisted_filters do |t|
      t.jsonb :body
      t.string :read_model

      t.timestamps
    end
  end
end