# frozen_string_literal: true

module Test
  module User
    class Aggregate < Yes::Core::Aggregate
      attribute :name, :string
      attribute :email, :email
      attribute :age, :integer
      attribute :active, :boolean
    end
  end
end
