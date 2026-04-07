# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module Role
          # @see Yes::Core::ReadModel::Builder
          class Builder < Yes::Core::ReadModel::Builder
            private

            def default_read_model_class
              Yes::Auth::Principals::Role
            end

            def aggregate_id_key
              'role_id'
            end
          end
        end
      end
    end
  end
end
