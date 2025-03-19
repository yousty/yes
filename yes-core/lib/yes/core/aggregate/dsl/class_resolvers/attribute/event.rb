# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Attribute
            # Creates and registers event classes for aggregate attributes
            #
            # This class resolver generates event classes that represent state changes
            # in aggregate attributes. Each event class is automatically configured
            # with a schema that validates the required attributes and their types.
            #
            # @example Generated event class structure
            #   class UserEmailUpdated < Yes::Core::Event
            #     def schema
            #       Dry::Schema.Params do
            #         required(:user_id).value(Yousty::Eventsourcing::Types::UUID)
            #         required(:email).value(String)
            #       end
            #     end
            #   end
            class Event < Base
              private

              # @return [Symbol] Returns :event as the class type
              def class_type
                :event
              end

              # @return [String] The name of the event class derived from the attribute
              def class_name
                attribute_data.event_name
              end

              # Generates a new event class with the required schema
              #
              # @return [Class] A new event class inheriting from Yes::Core::Event
              def generate_class
                context = context_name
                aggregate = aggregate_name
                attribute_name = attribute_data.name
                attribute_type = attribute_data.type

                Class.new(Yes::Core::Event) do
                  define_method :schema do
                    Dry::Schema.Params do
                      required(:"#{aggregate.underscore}_id").value(Yousty::Eventsourcing::Types::UUID)
                      if attribute_type == :aggregate
                        required(:"#{attribute_name}_id").value(Yousty::Eventsourcing::Types::UUID)
                      else
                        required(attribute_name).value(Yes::Core::TypeLookup.type_for(attribute_type, context, :event))
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
