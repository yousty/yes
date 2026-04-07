# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module User
          # @see Yes::Core::ReadModel::Builder
          class Builder < Yes::Core::ReadModel::Builder
            private

            def default_read_model_class
              Yes::Auth::Principals::User
            end

            def aggregate_id_key
              'principal_id'
            end
          end
        end
      end
    end
  end
end
