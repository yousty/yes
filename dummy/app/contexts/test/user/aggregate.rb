# frozen_string_literal: true

module Test
  module User
    class Aggregate < Yes::Core::Aggregate
      attribute :name, :string
      attribute :email, :email
      attribute :age, :integer
      attribute :active, :boolean

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
