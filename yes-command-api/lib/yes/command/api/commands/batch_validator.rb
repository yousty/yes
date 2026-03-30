# frozen_string_literal: true

module Yes
  module Command
    module Api
      module Commands
        # Validates a collection of commands using their respective validator classes.
        # Raises if any command is invalid.
        class BatchValidator
          CommandsInvalid = Class.new(Yes::Core::Error)

          class << self
            include Yes::Core::OpenTelemetry::Trackable

            # Validates the given commands, raises CommandsInvalid if any are invalid.
            #
            # @param commands [Array<Yes::Core::Command>] commands to validate
            # @raise [CommandsInvalid] if any command is invalid
            # @return [void]
            def call(commands)
              invalid = []
              commands.each do |command|
                validator = validator_for(command)
                next unless validator

                validator.call(command)
              rescue Yes::Core::Commands::Validator::CommandInvalid => e
                invalid << {
                  message: e.message,
                  command: command.class.to_s,
                  command_id: command.command_id,
                  data: command.payload,
                  metadata: command.metadata || {},
                  details: e.extra
                }.tap do
                  trace_error('Command validation failed', { command: command.to_json })
                end
              end

              return unless invalid.any?

              trace_error('Commands invalid', { invalid: invalid.to_json })
              raise CommandsInvalid.new(extra: invalid)
            end
            otl_trackable :call, Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Validate Commands')

            private

            # Returns the validator for the given command, or nil if none exists.
            #
            # @param command [Yes::Core::Command] command to validate
            # @return [Class, nil] validator class for the command, or nil
            def validator_for(command)
              class_name = Yes::Core::Commands::Helper.new(command).validator_classname

              Kernel.const_get(class_name)
            rescue NameError
              nil
            end

            # Traces an error on the current OpenTelemetry span.
            #
            # @param message [String] error message
            # @param attributes [Hash] span attributes
            # @return [void]
            def trace_error(message, attributes = {})
              singleton_class.current_span&.status = ::OpenTelemetry::Trace::Status.error(message)
              singleton_class.current_span&.add_attributes(attributes.stringify_keys)
            end
          end
        end
      end
    end
  end
end
