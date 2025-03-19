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
