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
                encrypted_attributes = command_data.encrypted_attributes || []

                Class.new(Yes::Core::Event) do
                  define_method :schema do
                    Dry::Schema.Params do
                      required_attribute = proc do |attr_name, type|
                        required(attr_name).value(Yes::Core::TypeLookup.type_for(type, context, :event))
                      end

                      optional_attribute = proc do |attr_name, type|
                        optional(attr_name).value(Yes::Core::TypeLookup.type_for(type, context, :event))
                      end

                      # Define the aggregate_id attribute for the event
                      required(:"#{aggregate.underscore}_id").value(Yousty::Eventsourcing::Types::UUID)

                      # Define payload attributes if any
                      payload_attributes.each do |attr_name, attr_type|
                        next required_attribute.call(attr_name, attr_type) unless attr_type.is_a?(Hash)
                        next optional_attribute.call(attr_name, attr_type[:type]) if attr_type[:optional]

                        required_attribute.call(attr_name, attr_type[:type])
                      end
                    end
                  end

                  # Add encryption_schema class method if there are encrypted attributes
                  if encrypted_attributes.any?
                    define_singleton_method :encryption_schema do
                      {
                        key: ->(data) { data[:"#{aggregate.underscore}_id"] },
                        attributes: encrypted_attributes
                      }
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
