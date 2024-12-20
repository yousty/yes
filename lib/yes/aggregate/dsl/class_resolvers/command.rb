# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      module ClassResolvers
        # Creates and registers command classes for attributes
        class Command < Base
          private

          def class_type
            :command
          end

          def class_name
            attribute.send(:command_name)
          end

          def generate_class
            context = context_name
            aggregate = aggregate_name
            attribute_name = attribute.send(:name)
            attribute_type = attribute.send(:type)

            Class.new(Yes::Command) do
              attribute :"#{aggregate.underscore}_id", Yousty::Eventsourcing::Types::UUID
              attribute attribute_name, Yes::TypeLookup.type_for(attribute_type, context)

              alias_method :subject_id, :"#{aggregate.underscore}_id"
            end
          end
        end
      end
    end
  end
end 