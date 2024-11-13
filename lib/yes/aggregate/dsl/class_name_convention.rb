# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      # Handles the naming conventions for aggregate-related classes
      #
      # @example
      #   convention = ClassNameConvention.new(context: 'MyContext', aggregate: 'User')
      #   convention.command_class_name('change_name') # => "MyContext::User::Commands::ChangeName::Command"
      #
      class ClassNameConvention
        # @param context [String] The context name
        # @param aggregate [String] The aggregate name
        def initialize(context:, aggregate:)
          @context = context
          @aggregate = aggregate
        end

        # Returns the conventional class name for a given type and name
        #
        # @param type [Symbol] The type of class (:command, :event, or :handler)
        # @param name [Symbol, String] The name of the class
        # @return [String] The conventional class name
        def class_name_for(type, name)
          case type
          when :command then command_class_name(name)
          when :event then event_class_name(name)
          when :handler then handler_class_name(name)
          end
        end

        private

        attr_reader :context, :aggregate

        def command_class_name(name)
          "#{context}::#{aggregate}::Commands::#{name.to_s.camelize}::Command"
        end

        def event_class_name(name)
          "#{context}::#{aggregate}::Events::#{name.to_s.camelize}"
        end

        def handler_class_name(name)
          "#{context}::#{aggregate}::Commands::#{name.to_s.camelize}::Handler"
        end
      end
    end
  end
end
