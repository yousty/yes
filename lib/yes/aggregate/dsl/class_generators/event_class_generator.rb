# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      module ClassGenerators
        # Generates event classes for attributes
        #
        # @api private
        class EventClassGenerator
          # @param context_name [String] The context name
          # @param aggregate_name [String] The aggregate name
          # @param attribute_name [Symbol] The attribute name
          # @param attribute_type [Symbol] The attribute type
          # @param event_name [Symbol] The event name
          def initialize(context_name:, aggregate_name:, attribute_name:, attribute_type:, event_name:)
            @context_name = context_name
            @aggregate_name = aggregate_name
            @attribute_name = attribute_name
            @attribute_type = attribute_type
            @event_name = event_name
          end

          # @return [Class] The generated event class
          def generate
            aggregate_name = @aggregate_name
            attribute_name = @attribute_name
            attribute_type = @attribute_type
            context_name = @context_name

            Class.new(Yes::Event) do
              define_method :schema do
                Dry::Schema.Params do
                  required(:"#{aggregate_name.underscore}_id").value(Yousty::Eventsourcing::Types::UUID)
                  required(attribute_name).value(Yes::TypeLookup.type_for(attribute_type, context_name, :event))
                end
              end
            end
          end
        end
      end
    end
  end
end
