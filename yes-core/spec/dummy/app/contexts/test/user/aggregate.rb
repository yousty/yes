# frozen_string_literal: true

module Test
  module User
    class Aggregate < Yes::Core::Aggregate
      read_model 'test_user'

      authorize do
        command.user_id == auth_data[:user_id]
      end

      attribute :name, :string, command: true
      attribute :email, :email, command: true
      attribute :age, :integer, command: true
      attribute :active, :boolean, command: true
      attribute :locale_test, :string, localized: true
      attribute :default_payload_test, :string
      attribute :dynamic_default_test, :datetime

      attribute :document_ids, :string
      attribute :another, :string

      command :approve_documents do
        payload document_ids: :string, another: :string

        authorize do
          command.another == auth_data[:name]
        end

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

      # uncomment for testing aggregate in console
      # attribute :location, :aggregate
      # command :assign_location do
      #   payload location_id: :uuid
      # end

      command :change, :shortcut_description do
        guard(
          :test_guard,
          error_extra: proc do
            {
              current_value: shortcut_description,
              new_value: payload.shortcut_description,
              expected_min_length: 4,
              new_value_length: payload.shortcut_description.size
            }
          end
        ) do
          payload.shortcut_description.size > 3
        end
      end
      command :change, :shortcuts_used, :integer
      command :activate, :shorcut_usage, attribute: :shortcut_usage_enabled
      command %i[enable disable], :shortcut_toggle
      command :publish

      command :test_command_with_locale do
        payload locale_test: :string, locale: :locale

        event :locale_test_changed
      end

      command :test_command_with_default_payload do
        payload default_payload_test: { type: :string, default: 'foo' }

        event :default_payload_test_changed
      end

      command :test_command_with_default_payload_and_other_attribute do
        payload name: :string, default_payload_test: { type: :string, default: 'bar' }

        event :default_payload_test_changed
      end

      command :test_dynamic_default do
        payload dynamic_default_test: { type: :datetime, default: -> { (Time.zone.now + 1.day).strftime('%Y-%m-%d %H:%M:%S') } }

        event :dynamic_default_test_changed
      end
    end
  end
end
