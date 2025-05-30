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
                  attribute :"#{aggregate.underscore}_id", Yousty::Eventsourcing::Types::UUID

                  # Define payload attributes if any
                  payload_attributes.each do |attr_name, attr_type|
                    if attr_type.is_a?(Hash) && attr_type[:optional]
                      attribute? attr_name, Yes::Core::TypeLookup.type_for(attr_type[:type], context).optional
                    else
                      attribute attr_name, Yes::Core::TypeLookup.type_for(attr_type, context)
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
