# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Command
            # Resolves or generates a command class for a command
            class Command < Base
              # Coercible::String silently coerces nil via Kernel.String(nil) → ""
              NIL_COERCING_TYPE_SYMBOLS = %i[string].freeze

              private

              # @return [Symbol] The type of class being resolved
              def class_type
                :command
              end

              # @return [String] The name of the class to be generated
              def class_name
                command_data.name
              end

              # Wraps a coercible type with a nil guard to prevent silent coercion
              #
              # @param type [Dry::Types::Type] The base type to guard
              # @param attr_name [Symbol] The attribute name for error messages
              # @return [Dry::Types::Type] The guarded type
              def nil_guarded(type, attr_name)
                type.prepend do |value|
                  if value.nil?
                    raise Dry::Types::CoercionError,
                          "nil is not allowed for '#{attr_name}'"
                  end

                  value
                end
              end

              # Resolves the type, applying a nil guard for coercible types when non-nullable
              #
              # @param base_type [Dry::Types::Type] The resolved dry-type
              # @param attr_name [Symbol] The attribute name for error messages
              # @param coercible [Boolean] Whether the type is coercible
              # @return [Dry::Types::Type] The type, optionally wrapped with a nil guard
              def guarded_type(base_type, attr_name, coercible)
                coercible ? nil_guarded(base_type, attr_name) : base_type
              end

              # Generates a command class
              #
              # @return [Class] The generated command class
              def generate_class # rubocop:disable Metrics/MethodLength
                context = context_name
                aggregate = aggregate_name
                payload_attributes = command_data.payload_attributes || {}
                guard = method(:guarded_type)

                Class.new(Yes::Core::Command) do
                  # Define the aggregate_id attribute for the command
                  attribute :"#{aggregate.underscore}_id", Yousty::Eventsourcing::Types::UUID

                  # Define payload attributes if any
                  payload_attributes.each do |attr_name, attr_type|
                    type_symbol = attr_type.is_a?(Hash) ? attr_type[:type] : attr_type
                    coercible = NIL_COERCING_TYPE_SYMBOLS.include?(type_symbol)

                    # Handle simple type (not a hash) — always required, non-nullable
                    unless attr_type.is_a?(Hash)
                      resolved_type = Yes::Core::TypeLookup.type_for(attr_type, context)
                      attribute attr_name, guard.call(resolved_type, attr_name, coercible)
                      next
                    end

                    resolved_type = Yes::Core::TypeLookup.type_for(attr_type[:type], context)

                    case [attr_type[:optional] == true, attr_type[:nullable] == true]
                    when [false, false]
                      # required key, non-nullable value
                      attribute attr_name, guard.call(resolved_type, attr_name, coercible)
                    when [false, true]
                      # required key, nullable value
                      attribute attr_name, resolved_type.optional
                    when [true, false]
                      # optional key, non-nullable value
                      attribute? attr_name, guard.call(resolved_type, attr_name, coercible)
                    when [true, true]
                      # optional key, nullable value
                      attribute? attr_name, resolved_type.optional
                    end
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
