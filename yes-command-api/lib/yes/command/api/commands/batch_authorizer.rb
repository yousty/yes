# frozen_string_literal: true

module Yes
  module Command
    module Api
      module Commands
        # Authorizes a collection of commands using their respective authorizer classes.
        # Raises if any command is not authorized.
        class BatchAuthorizer
          CommandsNotAuthorized = Class.new(Yes::Core::Error)
          CommandAuthorizerNotFound = Class.new(Yes::Core::Error)

          class << self
            include Yes::Core::OpenTelemetry::Trackable

            # Authorizes the given commands with the provided auth data.
            #
            # @param commands [Array<Yes::Core::Command>] commands to authorize
            # @param auth_data [Hash] authorization data
            # @raise [CommandsNotAuthorized] if any command is not authorized
            # @return [void]
            def call(commands, auth_data)
              unauthorized = []

              commands.each do |command|
                authorizer = authorizer_for(command)
                authorizer.call(command, auth_data)
              rescue CommandAuthorizerNotFound
                unauthorized << unauthorized_data(command, 'Not allowed').tap do
                  trace_error('Command authorizer not found', { command: command.to_json })
                end
              rescue Yes::Core::Authorization::CommandAuthorizer::CommandNotAuthorized => e
                unauthorized << unauthorized_data(command, e.message).tap do
                  trace_error('Command not authorized', { command: })
                end
              end

              return unless unauthorized.any?

              trace_error('Unauthorized', { unauthorized: unauthorized.to_json })
              raise CommandsNotAuthorized.new(extra: unauthorized)
            end
            otl_trackable :call, Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Authorize Commands')

            private

            # Returns the command authorizer for the given command.
            #
            # @param command [Yes::Core::Command] command to authorize
            # @return [Class] authorizer class for the command
            # @raise [CommandAuthorizerNotFound] if no authorizer is found
            def authorizer_for(command)
              class_name = Yes::Core::Commands::Helper.new(command).authorizer_classname

              Kernel.const_get(class_name)
            rescue NameError
              raise CommandAuthorizerNotFound, "#{class_name} not found"
            end

            # Builds unauthorized data hash for error reporting.
            #
            # @param command [Yes::Core::Command] the unauthorized command
            # @param message [String] the error message
            # @return [Hash] unauthorized data
            def unauthorized_data(command, message)
              {
                message:,
                command: command.class.to_s,
                command_id: command.command_id,
                data: command.payload,
                metadata: command.metadata || {}
              }
            end

            # Traces an error on the current OpenTelemetry span.
            #
            # @param message [String] error message
            # @param attributes [Hash] span attributes
            # @return [void]
            def trace_error(message, attributes)
              singleton_class.current_span&.status = ::OpenTelemetry::Trace::Status.error(message)
              singleton_class.current_span&.add_attributes(attributes.stringify_keys)
            end
          end
        end
      end
    end
  end
end
