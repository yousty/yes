# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module AttributeDefiners
          # Handles the definition and generation of standard attribute-related classes and methods
          class Standard < Base
            private

            # Defines methods for standard attributes
            #
            # @return [void]
            def define_methods
              AttributeMethodDefiners::ChangeCommand.new(attribute_data).call
              AttributeMethodDefiners::CanChangeCommand.new(attribute_data).call
              AttributeMethodDefiners::Accessor.new(attribute_data).call
            end
          end
        end
      end
    end
  end
end
