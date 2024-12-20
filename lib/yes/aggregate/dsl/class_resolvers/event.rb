# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      module ClassResolvers
        # Creates and registers event classes for attributes
        class Event < Base
          private

          def class_type
            :event
          end

          def class_name
            attribute.send(:event_name)
          end

          def generate_class
            context = context_name
            aggregate = aggregate_name
            attribute_name = attribute.send(:name)
            attribute_type = attribute.send(:type)

            Class.new(Yes::Event) do
              define_method :schema do
                Dry::Schema.Params do
                  required(:"#{aggregate.underscore}_id").value(Yousty::Eventsourcing::Types::UUID)
                  required(attribute_name).value(Yes::TypeLookup.type_for(attribute_type, context, :event))
                end
              end
            end
          end
        end
      end
    end
  end
end 