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
            # For aggregates, we define:
            # - A change command that accepts an aggregate instance
            # - A change command for the ID
            # - Can change commands for both the aggregate and ID
            # - Accessors for both the aggregate and ID
            #
            # @return [void]
            def define_methods
              AttributeMethodDefiners::ChangeAggregateCommand.new(attribute_data).call
              define_aggregate_id_methods
              AttributeMethodDefiners::CanChangeAggregateCommand.new(attribute_data).call
              AttributeMethodDefiners::AggregateAccessor.new(attribute_data).call
            end

            # Defines methods specifically for the aggregate ID
            # This creates separate commands that use the _id suffix
            #
            # @return [void]
            def define_aggregate_id_methods
              id_attribute_data = attribute_data.dup
              id_attribute_data.define_singleton_method(:name) { :"#{super()}_id" }
              id_attribute_data.define_singleton_method(:type) { :uuid }

              AttributeMethodDefiners::ChangeCommand.new(id_attribute_data).call
              AttributeMethodDefiners::CanChangeCommand.new(id_attribute_data).call
            end
          end
        end
      end
    end
  end
end
