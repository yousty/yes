# frozen_string_literal: true

module Yes
  module Read
    module Api
      class ModelConstraints
        class << self
          # @param request [ActionDispatch::Request]
          def matches?(request)
            Rails.application.config.yes_read_api.read_models.include?(request.params['model'])
          end
        end
      end
    end
  end
end
