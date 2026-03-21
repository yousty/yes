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
                  # Define the aggregate_id attribute for the command
                  attribute :"#{aggregate.underscore}_id", Yes::Core::Types::UUID

                  # Define payload attributes if any
                  payload_attributes.each do |attr_name, attr_type|
                    # Handle simple type (not a hash)
                    unless attr_type.is_a?(Hash)
                      attribute attr_name, Yes::Core::TypeLookup.type_for(attr_type, context)
                      next
                    end

                    resolved_type = Yes::Core::TypeLookup.type_for(attr_type[:type], context)

                    case [attr_type[:optional] == true, attr_type[:nullable] == true]
                    when [false, false]
                      # required key, non-nullable value
                      attribute attr_name, resolved_type
                    when [false, true]
                      # required key, nullable value
                      attribute attr_name, resolved_type.optional
                    when [true, false]
                      # optional key, non-nullable value
                      attribute? attr_name, resolved_type
                    when [true, true]
                      # optional key, nullable value
                      attribute? attr_name, resolved_type.optional
                    end
                  end

                  alias_method :aggregate_id, :"#{aggregate.underscore}_id"
                  alias_method :subject_id, :aggregate_id
                end
              end
            end
          end
        end
      end
    end
  end
end
