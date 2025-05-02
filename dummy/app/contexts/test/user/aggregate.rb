# frozen_string_literal: true

module Test
  module User
    class Aggregate < Yes::Core::Aggregate
      authorize do
        command.user_id == auth_data[:user_id]
      end

      attribute :name, :string, command: true
      attribute :email, :email, command: true
      attribute :age, :integer, command: true
      attribute :active, :boolean, command: true

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

      # uncomment for testing guard in console
      # attribute :location, :aggregate do
      #   guard :something do
      #     name == 'John'
      #   end

      #   guard :something2 do
      #     payload.location.name == 'London'
      #   end
      # end
    end
  end
end
