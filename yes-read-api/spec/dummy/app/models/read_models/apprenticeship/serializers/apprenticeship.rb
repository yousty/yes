# frozen_string_literal: true

module ReadModels
  module Apprenticeship
    module Serializers
      class Apprenticeship < Yes::Core::Serializer
        set_type :apprenticeships

        belongs_to :company, serializer: Company

        attributes :company_id, :dropout_enabled
      end
    end
  end
end
