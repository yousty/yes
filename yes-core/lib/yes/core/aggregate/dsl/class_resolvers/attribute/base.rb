# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Attribute
            # Base class for creating attribute-related aggregate classes
            #
            # This class extends the base resolver functionality to handle
            # attribute-specific class generation. It provides a foundation for
            # resolvers that need to work with aggregate attributes, such as
            # commands, events, and handlers that operate on specific attributes.
            #
            # @abstract Subclass and implement the required methods from {ClassResolvers::Base}
            class Base < ClassResolvers::Base
              # Initializes a new attribute-based class resolver
              #
              # @param attribute_data [Yes::Core::Aggregate::Dsl::AttributeData] The attribute instance
              #   containing metadata about the attribute being processed
              def initialize(attribute_data)
                @attribute_data = attribute_data

                super(attribute_data.context_name, attribute_data.aggregate_name)
              end

              private

              # @return [Yes::Core::Aggregate::Dsl::AttributeData] The attribute instance
              attr_reader :attribute_data
            end
          end
        end
      end
    end
  end
end
