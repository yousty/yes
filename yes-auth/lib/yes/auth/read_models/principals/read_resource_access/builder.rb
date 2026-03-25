# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module ReadResourceAccess
          # @see Yes::Core::ReadModel::Builder
          class Builder < Yes::Core::ReadModel::Builder
            private

            def default_read_model_class
              Yes::Auth::Principals::ReadResourceAccess
            end

            def aggregate_id_key
              'read_resource_access_id'
            end
          end
        end
      end
    end
  end
end
