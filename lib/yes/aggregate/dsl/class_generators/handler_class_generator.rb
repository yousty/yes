# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      module ClassGenerators
        # Generates handler classes for attributes
        #
        # @api private
        class HandlerClassGenerator
          # @param context_name [String] The context name
          # @param aggregate_name [String] The aggregate name
          # @param attribute_name [Symbol] The attribute name
          # @param event_name [Symbol] The event name
          def initialize(context_name:, aggregate_name:, attribute_name:, event_name:)
            @context_name = context_name
            @aggregate_name = aggregate_name
            @attribute_name = attribute_name
            @event_name = event_name
          end

          # @return [Class] The generated handler class
          def generate # rubocop:disable Metrics/AbcSize
            aggregate_name = @aggregate_name
            attribute_name = @attribute_name
            event_name = @event_name

            Class.new(Yes::CommandHandler) do
              self.event_name = event_name.to_s.camelize

              define_method :call do
                send(:"check_#{attribute_name}_is_not_changing")
                super()
              end

              define_method :"check_#{attribute_name}_is_not_changing" do
                if no_change?(
                  subject_data,
                  { :"#{aggregate_name.underscore}_id" => attributes["#{aggregate_name.underscore}_id"],
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
