# frozen_string_literal: true

module Test
  module User
    class Aggregate < Yes::Core::Aggregate
      attribute :name, :string, command: true
      attribute :email, :email, command: true
      attribute :age, :integer, command: true
      attribute :active, :boolean, command: true

      attribute :document_ids, :string
      attribute :another, :string

      command :approve_documents do
        payload document_ids: :string, another: :string

        # guard :something do
        #   payload.another == 'John'
        # end
      end

      command :approve_documents_with_custom_event do
        event :document_happily_approved
      end

      command :some_custom_command do
        payload another: :string

        event :some_custom_event
      end

      # uncomment for testing guard in console
      # attribute :location, :aggregate do
      #   guard :something do
      #     name == 'John'
      #   end

      #   guard :something2 do
      #     payload.location.name == 'London'
      #   end
      # end

      command :change, :shortcut_description do
        guard(:test_guard) { payload.shortcut_description.size > 3 }
      end
      command :change, :shortcuts_used, :integer
      command :activate, :shorcut_usage, attribute: :shortcut_usage_enabled
      command %i[enable disable], :shortcut_toggle
      command :publish
    end
  end
end
