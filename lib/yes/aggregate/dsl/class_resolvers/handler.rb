# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      module ClassResolvers
        # Creates and registers handler classes for attributes
        class Handler < Base
          private

          def class_type
            :handler
          end

          def class_name
            attribute.send(:command_name)
          end

          def generate_class # rubocop:disable Metrics/AbcSize
            aggregate = aggregate_name
            attribute_name = attribute.send(:name)
            event_name = attribute.send(:event_name)

            Class.new(Yes::CommandHandler) do
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