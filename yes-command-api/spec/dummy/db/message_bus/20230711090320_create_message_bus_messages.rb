# frozen_string_literal: true

class CreateMessageBusMessages < ActiveRecord::Migration[7.0]
  def up
    create_table "message_bus_messages" do |t|
      t.text :channel, null: false
      t.jsonb :value, null: false
      t.datetime :added_at, null: false
    end
    execute("ALTER TABLE #{"message_bus_messages"} ALTER COLUMN added_at SET DEFAULT CURRENT_TIMESTAMP")
    add_index "message_bus_messages", [:id, :channel]
    add_index "message_bus_messages", :added_at
  end

  def down
    drop_table "message_bus_messages"
  end
end
