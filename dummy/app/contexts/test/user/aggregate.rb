# frozen_string_literal: true

module Test
  module User
    class Aggregate < Yes::Aggregate
      attribute :name, :string
      attribute :email, :email
      attribute :age, :integer
      attribute :active, :boolean
      attribute :something, :string # missing from read model
    end
  end
end
