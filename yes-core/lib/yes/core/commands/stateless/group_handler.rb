# frozen_string_literal: true

module Yes
  module Core
    module Commands
      module Stateless
        # Handles a group of commands
        class GroupHandler
          include HandlerHelpers

          class InvalidCommandGroupError < Error
            def initialize(cmd_module_name, handler_module_name)
              super("command #{cmd_module_name} does not match handler #{handler_module_name}")
            end
          end

          class CustomHandlerMethodMissingError < Error; end
          class CommandsError < Error; end

          class << self
            # @return [Array<Symbol, Class>] List of handlers for the command group
            attr_reader :handlers

            # @return [Boolean] Always returns true for stateless handlers
            def stateless?
              true
            end

            # Adds a handler to the command group
            # @param command_or_handler_method_name [Symbol, String] the name of the command class (String) or custom handler method (Symbol)
            # @param context [Symbol, String] the context of the handler's command, camel or snake case
            # @param subject [Symbol, String] the subject of the handler's command, camel or snake case
            # @return [void]
            def handler(command_or_handler_method_name, context: to_s.split('::')[0],
                        subject: to_s.split('::')[1])
              @handlers ||= []
              @handlers << build_handler(command_or_handler_method_name, context, subject)
            end

            private

            # Builds a handler class or returns a symbol for the command, representing a custom handler method
            # @param command_or_handler_name [Symbol, String] the name of the command class (String) or custom handler method (Symbol)
            # @param context [String] the context of the handler's command
            # @param subject [String] the subject of the handler's command
            # @return [Class, Symbol] the handler class or a symbol representing the command
            def build_handler(command_or_handler_name, context, subject)
              return command_or_handler_name if command_or_handler_name.is_a?(Symbol)

              Object.const_get(
                "#{context}::#{subject}::Commands::#{command_or_handler_name}::Handler"
              )
            end
          end

          # @param cmd [Group] the command group to handle
          # @param events_cache [Hash] already cached events
          #  { stream => { event_name => event_data } }
          # @raise [InvalidCommandGroupError] if the command is not valid
          def initialize(cmd, events_cache: {})
            unless valid_command?(cmd)
              raise InvalidCommandGroupError.new(cmd.class.name.deconstantize, self.class.name.deconstantize)
            end

            @cmd = cmd
            @events_cache = events_cache
          end

          # Executes the command group
          # @raise [CommandsError] if any handler errors occur during execution
          # @return [void]
          def call
            errors = []

            PgEventstore.client.multiple do
              errors.push(*run_command_handlers)
              errors.push(*run_custom_handlers)
              raise CommandsError.new(extra: errors), 'Command group failed' if errors.any?

              publish_events
            end
          end

          private

          attr_reader :cmd, :events_cache

          # Runs the defined command handlers for each command in the group
          # @return [Array] updated errors array
          def run_command_handlers
            cmd.commands.each_with_object([]) do |command, errors|
              handler_class(command.class).new(command, publish_events: false).call
            rescue Handler::InvalidTransition, Handler::NoChangeTransition => e
              errors << { command: command.class.name, error: e.message, extra: e.extra }
            end
          end

          # Runs any custom handlers defined for the command group
          # @return [Array] updated errors array
          def run_custom_handlers
            custom_handlers.each_with_object([]) do |custom_handler, errors|
              send(custom_handler)
            rescue NoMethodError
              raise CustomHandlerMethodMissingError, "Method #{custom_handler} not found"
            rescue Handler::InvalidTransition, Handler::NoChangeTransition => e
              errors << { custom_handler:, error: e.message, extra: e.extra }
            end
          end

          # Publishes events for all commands in the group
          # @return [void]
          def publish_events
            cmd.commands.each do |command|
              handler = handler_class(command.class).new(command, revision_check: false)
              # only run base class call method which publishes events
              Handler.instance_method(:call).bind_call(handler)
            end
          end

          # Checks if the given command is valid for this handler
          # @param cmd [Group] the command group to validate
          # @return [Boolean] true if the command is valid, false otherwise
          def valid_command?(cmd)
            cmd.is_a?(Group) && cmd.class.name.deconstantize == self.class.name.deconstantize
          end

          # Gets the handler class for a given command class
          # @param command_class [Class] the command class
          # @return [Class] the handler class for the command
          def handler_class(command_class)
            handler = handler_for(command_class)
            default_handlers.find { _1 == handler } || Class.new(Handler) { self.event_name = handler.event_name }
          end

          # Gets the handler for a given command class
          # @param command_class [Class] the command class
          # @return [Class] the handler class for the command
          def handler_for(command_class)
            Object.const_get("#{command_class.name.deconstantize}::Handler")
          end

          # @return [Array<Class>] list of default handlers
          def default_handlers
            self.class.handlers.without(custom_handlers)
          end

          # @return [Array<Symbol>] list of custom handlers
          def custom_handlers
            self.class.handlers.select { _1.is_a?(Symbol) }
          end

          # Raises an InvalidTransition error
          # @param message [String] the error message
          # @param extra [Hash] additional error information
          # @raise [Handler::InvalidTransition] always raised
          def invalid_transition(message, extra: {})
            raise Handler::InvalidTransition.new(extra:), message.to_s
          end

          # Raises a NoChangeTransition error
          # @param message [String] the error message
          # @param extra [Hash] additional error information
          # @raise [Handler::NoChangeTransition] always raised
          def no_change_transition(message, extra: {})
            raise Handler::NoChangeTransition.new(extra:), message.to_s
          end

          # Returns a subject object composed based on the command group handler class
          # @param context [String] the context of the subject
          # @param subject [String] the subject of the command group
          # @param subject_id [String] the id of the subject
          # @param stream_prefix [String] the stream prefix of the subject
          # @return [Yes::Core::Commands::Stateless::Subject] the subject object
          def subject_data(
            context: self.class.to_s.split('::')[0],
            subject: self.class.to_s.split('::')[1],
            subject_id: nil,
            stream_prefix: nil
          )
            Yes::Core::Commands::Stateless::Subject.new(
              context:, subject:, stream_prefix:, subject_id:
            )
          end
        end
      end
    end
  end
end
