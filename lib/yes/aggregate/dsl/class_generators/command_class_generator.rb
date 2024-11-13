# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      module ClassGenerators
        # Generates command classes for attributes
        #
        # @api private
        class CommandClassGenerator
          # @param context_name [String] The context name
          # @param aggregate_name [String] The aggregate name
          # @param attribute_name [Symbol] The attribute name
          # @param attribute_type [Symbol] The attribute type
          def initialize(context_name:, aggregate_name:, attribute_name:, attribute_type:)
            @context_name = context_name
            @aggregate_name = aggregate_name
            @attribute_name = attribute_name
            @attribute_type = attribute_type
          end

          # @return [Class] The generated command class
          def generate
            context_name = @context_name
            aggregate_name = @aggregate_name
            attribute_name = @attribute_name
            attribute_type = @attribute_type

            Class.new(Yes::Command) do
              attribute :"#{aggregate_name.underscore}_id", Yousty::Eventsourcing::Types::UUID
              attribute attribute_name, Yes::TypeLookup.type_for(attribute_type, context_name)

              alias_method :subject_id, :"#{aggregate_name.underscore}_id"
            end
          end
        end
      end
    end
  end
end
