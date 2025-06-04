# frozen_string_literal: true

module ReadModels
  module Apprenticeship
    module Serializers
      class Company < Yousty::Api::ApplicationSerializer
        set_type :companies

        attributes :name
      end
    end
  end
end
