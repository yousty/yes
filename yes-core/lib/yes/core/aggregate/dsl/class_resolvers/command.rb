# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          # Creates and registers command classes for aggregate attributes
          #
          # This class resolver generates command classes that handle attribute
          # modifications in aggregates. Each command class is automatically
          # configured with the necessary attributes and type validations.
          #
          # @example Generated command class structure
          #   class UpdateUserEmail < Yes::Core::Command
          #     attribute :user_id, Yousty::Eventsourcing::Types::UUID
          #     attribute :email, String
          #
          #     alias_method :subject_id, :user_id
          #   end
          class Command < AttributeBase
            private

            # @return [Symbol] Returns :command as the class type
            def class_type
              :command
            end

            # @return [String] The name of the command class derived from the attribute
            def class_name
              attribute.send(:command_name)
            end

            # Generates a new command class with the required attributes
            #
            # @return [Class] A new command class inheriting from Yes::Core::Command
            def generate_class
              context = context_name
              aggregate = aggregate_name
              attribute_name = attribute.send(:name)
              attribute_type = attribute.send(:type)

              Class.new(Yes::Core::Command) do
                attribute :"#{aggregate.underscore}_id", Yousty::Eventsourcing::Types::UUID
                if attribute_type == :aggregate
                  attribute :"#{attribute_name}_id", Yousty::Eventsourcing::Types::UUID
                else
                  attribute attribute_name, Yes::Core::TypeLookup.type_for(attribute_type, context)
                end

                alias_method :subject_id, :"#{aggregate.underscore}_id"
              end
            end
          end
        end
      end
    end
  end
end
