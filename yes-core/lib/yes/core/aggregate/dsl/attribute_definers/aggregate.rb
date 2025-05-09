# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module AttributeDefiners
          # Handles the definition and generation of aggregate attribute-related classes and methods
          class Aggregate < Base
            private

            # Defines methods for aggregate type attributes
            #
            # @return [void]
            def define_methods
              MethodDefiners::Attribute::AggregateAccessor.new(attribute_data).call
            end
          end
        end
      end
    end
  end
end
