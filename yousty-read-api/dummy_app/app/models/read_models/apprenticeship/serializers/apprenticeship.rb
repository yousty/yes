# frozen_string_literal: true

module ReadModels
  module Apprenticeship
    module Serializers
      class Apprenticeship < Yousty::Api::ApplicationSerializer
        set_type :apprenticeships

        belongs_to :company, serializer: Company

        attributes :company_id, :dropout_enabled
      end
    end
  end
end
