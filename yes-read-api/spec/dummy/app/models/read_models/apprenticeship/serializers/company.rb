# frozen_string_literal: true

module ReadModels
  module Apprenticeship
    module Serializers
      class Company < Yes::Core::Serializer
        set_type :companies

        attributes :name
      end
    end
  end
end
