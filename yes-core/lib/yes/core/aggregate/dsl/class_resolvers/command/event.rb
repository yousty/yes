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
                      # Helper to build attribute definition with support for optional key and nullable value
                      build_attribute = proc do |attr_name, attr_type_config|
                        # Handle simple type (not a hash)
                        unless attr_type_config.is_a?(Hash)
                          required(attr_name).value(Yes::Core::TypeLookup.type_for(attr_type_config, context, :event))
                          next
                        end

                        resolved_type = Yes::Core::TypeLookup.type_for(attr_type_config[:type], context, :event)

                        case [attr_type_config[:optional] == true, attr_type_config[:nullable] == true]
                        when [false, false]
                          # required key, non-nullable value
                          required(attr_name).value(resolved_type)
                        when [false, true]
                          # required key, nullable value
                          required(attr_name).maybe(resolved_type)
                        when [true, false]
                          # optional key, non-nullable value
                          optional(attr_name).value(resolved_type)
                        when [true, true]
                          # optional key, nullable value
                          optional(attr_name).maybe(resolved_type)
                        end
                      end

                      # Define the aggregate_id attribute for the event
                      required(:"#{aggregate.underscore}_id").value(Yes::Core::Types::UUID)

                      # Define payload attributes if any
                      payload_attributes.each do |attr_name, attr_type|
                        build_attribute.call(attr_name, attr_type)
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
