# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          # Creates and registers handler classes for aggregate attributes
          #
          # This class resolver generates command handler classes that process
          # attribute modifications in aggregates. Each handler class is automatically
          # configured with validation logic to check if the attribute value is
          # actually changing before emitting an event.
          #
          # @example Generated handler class structure
          #   class ChangeUserEmailHandler < Yes::Core::CommandHandler
          #     self.event_name = 'UserEmailChanged'
          #
          #     def call
          #       check_email_is_not_changing
          #       super()
          #     end
          #
          #     def check_email_is_not_changing
          #       if no_change?(subject_data, { user_id: attributes['user_id'], email: attributes['email'] }, 'UserEmailChanged')
          #         no_change_transition('Email is not changing')
          #       end
          #     end
          #   end
          class Handler < AttributeBase
            private

            # @return [Symbol] Returns :handler as the class type
            def class_type
              :handler
            end

            # @return [String] The name of the handler class derived from the attribute
            def class_name
              attribute.send(:command_name)
            end

            # Generates a new handler class with the required validation methods
            #
            # @return [Class] A new handler class inheriting from Yes::Core::CommandHandler
            def generate_class # rubocop:disable Metrics/AbcSize
              aggregate = aggregate_name
              attribute_name = attribute.send(:name)
              event_name = attribute.send(:event_name)

              Class.new(Yes::Core::CommandHandler) do
                self.event_name = event_name.to_s.camelize

                define_method :call do
                  send(:"check_#{attribute_name}_is_not_changing")
                  super()
                end

                define_method :"check_#{attribute_name}_is_not_changing" do
                  if no_change?(
                    subject_data,
                    { :"#{aggregate.underscore}_id" => attributes["#{aggregate.underscore}_id"],
                      attribute_name => attributes[attribute_name.to_s] },
                    event_name.to_s.camelize
                  )
                    no_change_transition("#{attribute_name.to_s.humanize} is not changing")
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
