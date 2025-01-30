# frozen_string_literal: true

module ReadModels
  module Company
    module Serializers
      class Company < Yousty::Api::ApplicationSerializer
        set_type :companies

        attributes :name, :available_apprenticeship_slots
      end
    end
  end
end
