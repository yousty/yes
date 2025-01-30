# frozen_string_literal: true

module Universe
  module Star
    class Aggregate < Yes::Core::Aggregate
      attribute :label, :string
      attribute :size, :integer
    end
  end
end
