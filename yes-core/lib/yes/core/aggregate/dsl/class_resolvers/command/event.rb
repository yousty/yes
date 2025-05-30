# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Command
            # Resolves or generates an event class for a command
            class Event < Base
              private

              # @return [Symbol] The type of class being resolved
              def class_type
                :event
              end

              # @return [String] The name of the class to be generated
              def class_name
                command_data.event_name
              end

              # Generates an event class
              #
              # @return [Class] The generated event class
              def generate_class
                aggregate = aggregate_name
                context = context_name
                payload_attributes = command_data.payload_attributes || {}

                Class.new(Yes::Core::Event) do
                  define_method :schema do
                    Dry::Schema.Params do
                      # Define the aggregate_id attribute for the event
                      required(:"#{aggregate.underscore}_id").value(Yousty::Eventsourcing::Types::UUID)

                      # Define payload attributes if any
                      payload_attributes.each do |attr_name, attr_type|
                        if attr_type.is_a?(Hash) && attr_type[:optional]
                          optional(attr_name).value(Yes::Core::TypeLookup.type_for(attr_type[:type], context, :event))
                        else
                          required(attr_name).value(Yes::Core::TypeLookup.type_for(attr_type, context, :event))
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
