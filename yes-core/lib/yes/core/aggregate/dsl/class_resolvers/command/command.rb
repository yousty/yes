# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Command
            # Resolves or generates a command class for a command
            class Command < Base
              private

              # @return [Symbol] The type of class being resolved
              def class_type
                :command
              end

              # @return [String] The name of the class to be generated
              def class_name
                command_data.name
              end

              # Generates a command class
              #
              # @return [Class] The generated command class
              def generate_class
                context = context_name
                aggregate = aggregate_name
                payload_attributes = command_data.payload_attributes || {}

                Class.new(Yes::Core::Command) do
                  # Type symbols that use Coercible types and silently coerce nil
                  # (e.g., nil.to_s → "", nil.to_i → 0)
                  coercible_type_symbols = %i[string integer float lat lng].freeze

                  # Define the aggregate_id attribute for the command
                  attribute :"#{aggregate.underscore}_id", Yousty::Eventsourcing::Types::UUID

                  define_singleton_method :optional_attribute do |attr_name, type|
                    attribute? attr_name, Yes::Core::TypeLookup.type_for(type, context).optional
                  end

                  define_singleton_method :nullable_attribute do |attr_name, type|
                    attribute attr_name, Yes::Core::TypeLookup.type_for(type, context).optional
                  end

                  define_singleton_method :required_attribute do |attr_name, type_symbol|
                    base_type = Yes::Core::TypeLookup.type_for(type_symbol, context)
                    resolved_type = if coercible_type_symbols.include?(type_symbol)
                                      base_type.prepend do |value|
                                        if value.nil?
                                          raise Dry::Types::CoercionError,
                                                "nil is not allowed for '#{attr_name}'"
                                        end

                                        value
                                      end
                                    else
                                      base_type
                                    end
                    attribute attr_name, resolved_type
                  end

                  # Define payload attributes if any
                  payload_attributes.each do |attr_name, attr_type|
                    next required_attribute attr_name, attr_type unless attr_type.is_a?(Hash)
                    next optional_attribute attr_name, attr_type[:type] if attr_type[:optional]
                    next nullable_attribute attr_name, attr_type[:type] if attr_type[:nullable]

                    required_attribute attr_name, attr_type[:type]
                  end

                  # TODO: Legacy: Change to :aggregate_id - requires chnage in yousty es in many places
                  alias_method :subject_id, :"#{aggregate.underscore}_id"
                end
              end
            end
          end
        end
      end
    end
  end
end
