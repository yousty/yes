# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      # Handles the definition and generation of attribute-related classes for aggregates
      # This includes commands, events, and handlers for attribute changes.
      #
      # @example
      #   Attribute.define(:name, :string, validate: true)
      #
      class Attribute
        # Defines a new attribute and generates all necessary classes
        #
        # @param name [Symbol] The name of the attribute
        # @param type [Symbol] The type of the attribute (e.g., :string, :integer)
        # @param aggregate_class [Class] The aggregate class to define the attribute on
        # @param options [Hash] Additional options for the attribute
        # @option options [String] :context The context name for the attribute
        # @option options [String] :aggregate The aggregate name
        # @return [void]
        def self.define(name, type, aggregate_class, **options)
          new(name, type, aggregate_class, options).define
        end

        # @param name [Symbol] The name of the attribute
        # @param type [Symbol] The type of the attribute
        # @param aggregate_class [Class] The aggregate class to define the attribute on
        # @param options [Hash] Additional options for the attribute
        # @option options [String] :context The context name for the attribute
        # @option options [String] :aggregate The aggregate name
        def initialize(name, type, aggregate_class, options)
          @name = name
          @type = type
          @aggregate_class = aggregate_class
          @options = options
          @command_name = :"change_#{name}"
          @event_name = :"#{name}_changed"
          @context_name = options.delete(:context)
          @aggregate_name = options.delete(:aggregate)
          @class_name_convention = ClassNameConvention.new(
            context: context_name,
            aggregate: aggregate_name
          )
          @constant_resolver = ConstantResolver.new(class_name_convention)
        end

        # Generates and registers all necessary classes for the attribute
        # This includes a command class, event class, and handler class
        #
        # @return [void]
        def define
          register_generated_classes(
            find_or_generate_command_class,
            find_or_generate_event_class,
            find_or_generate_handler_class
          )
          define_change_command_method(name, aggregate_class)
          define_can_change_command_method(name, aggregate_class)
        end

        private

        attr_reader :name, :type, :options, :command_name, :event_name, :context_name, :aggregate_name,
                    :class_name_convention, :constant_resolver, :aggregate_class

        # Attempts to find an existing command class or generates a new one
        #
        # @return [Class] The command class
        def find_or_generate_command_class
          constant_resolver.find_conventional_class(:command, command_name) ||
            constant_resolver.set_constant_for(:command, command_name, generate_command_class)
        end

        # Attempts to find an existing event class or generates a new one
        #
        # @return [Class] The event class
        def find_or_generate_event_class
          constant_resolver.find_conventional_class(:event, event_name) ||
            constant_resolver.set_constant_for(:event, event_name, generate_event_class)
        end

        # Attempts to find an existing handler class or generates a new one
        #
        # @return [Class] The handler class
        def find_or_generate_handler_class
          constant_resolver.find_conventional_class(:handler, command_name) ||
            constant_resolver.set_constant_for(:handler, command_name, generate_handler_class)
        end

        # Generates a new command class for the attribute
        #
        # @return [Class] The generated command class
        def generate_command_class
          ClassGenerators::CommandClassGenerator.new(
            context_name:,
            aggregate_name:,
            attribute_name: name,
            attribute_type: type
          ).generate
        end

        # Generates a new event class for the attribute
        #
        # @return [Class] The generated event class
        def generate_event_class
          ClassGenerators::EventClassGenerator.new(
            context_name:,
            aggregate_name:,
            attribute_name: name,
            attribute_type: type,
            event_name:
          ).generate
        end

        # Generates a new handler class for the attribute
        #
        # @return [Class] The generated handler class
        def generate_handler_class
          ClassGenerators::HandlerClassGenerator.new(
            context_name:,
            aggregate_name:,
            attribute_name: name,
            event_name:
          ).generate
        end

        # Registers the generated classes with the Yes configuration
        #
        # @param command_class [Class] The command class to register
        # @param event_class [Class] The event class to register
        # @param handler_class [Class] The handler class to register
        # @return [void]
        def register_generated_classes(command_class, event_class, handler_class)
          Yes.configuration.register_aggregate_class(context_name, aggregate_name, command_name, :command,
                                                     command_class)
          Yes.configuration.register_aggregate_class(context_name, aggregate_name, event_name, :event, event_class)
          Yes.configuration.register_aggregate_class(context_name, aggregate_name, command_name, :handler,
                                                     handler_class)
        end

        # Defines a change command method on the aggregate class
        #
        # @param name [Symbol] The name of the attribute
        # @param aggregate_class [Class] The aggregate class to define the method on
        # @return [Yousty::Eventsourcing::Command::Event, false] The event if the change is successful, false otherwise
        def define_change_command_method(name, aggregate_class)
          command_method = "change_#{name}"

          aggregate_class.define_method(command_method) do |**payload|
            return false unless send(:"can_change_#{name}?", **payload)

            command = build_command(name, payload)
            handler_class = fetch_handler_class(name)
            handler = handler_class.new(command, revision_check: false)
            # only run base class call method which publishes events
            Yes::CommandHandler.instance_method(:call).bind_call(handler)
          end
        end

        # Defines a method that checks if an attribute can be changed
        #
        # @param name [Symbol] The name of the attribute
        # @param aggregate_class [Class] The aggregate class to define the method on
        # @return [true, false] true if the change is valid, false otherwise
        def define_can_change_command_method(name, aggregate_class)
          can_change_method = "can_change_#{name}?"
          error_method = "#{name}_change_error"

          # Define the error accessor method
          aggregate_class.attr_accessor error_method

          aggregate_class.define_method(can_change_method) do |**payload|
            command = build_command(name, payload)
            handler_class = fetch_handler_class(name)

            handler_class.new(command, publish_events: false).call
            send(:"#{error_method}=", nil)
            true
          rescue CommandHandler::InvalidTransition, CommandHandler::NoChangeTransition,
                 Yousty::Eventsourcing::Command::Invalid => e
            send(:"#{error_method}=", e.message)
            false
          end
        end
      end
    end
  end
end
