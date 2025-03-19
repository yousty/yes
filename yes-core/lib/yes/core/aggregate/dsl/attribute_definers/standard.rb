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
              MethodDefiners::Attribute::Accessor.new(attribute_data).call

              return unless define_command?

              MethodDefiners::Attribute::ChangeCommand.new(attribute_data).call
              MethodDefiners::Attribute::CanChangeCommand.new(attribute_data).call
            end
          end
        end
      end
    end
  end
end
