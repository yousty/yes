# frozen_string_literal: true

module Yes
  module Command
    module Api
      module Commands
        # Deserializes command data hashes into command instances.
        # Supports V1, V2, and command group class resolution.
        class Deserializer
          DeserializationFailed = Class.new(Yes::Core::Error)

          class << self
            include Yes::Core::OpenTelemetry::Trackable

            # Deserializes command data into command instances.
            #
            # @param command_data [Array<Hash>] commands to deserialize
            # @return [Array<Yes::Core::Command>] deserialized commands
            # @raise [DeserializationFailed] if any command cannot be deserialized
            def call(command_data)
              failed = { invalid: [], not_found: [] }
              commands = []

              command_data.each do |command|
                commands << Kernel.const_get(command_class_name(command)).new(
                  { metadata: command[:metadata] }.merge(command[:data])
                ).tap do |cmd|
                  singleton_class.current_span&.add_event('Deserialized',
                                                          attributes: { 'command' => cmd.to_json })
                end
              rescue NameError
                failed[:not_found] << command
              rescue Yes::Core::Command::Invalid
                failed[:invalid] << command
              end

              if failed.values.flatten.any?
                singleton_class.current_span&.status = ::OpenTelemetry::Trace::Status.error('Deserialization failed')
                singleton_class.current_span&.add_attributes({ 'failed' => failed.to_json })

                raise DeserializationFailed.new(extra: failed)
              end

              commands
            end
            otl_trackable :call, Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Deserialize Commands')

            private

            # Resolves the command class name, trying command group, V2, then V1 conventions.
            #
            # @param command [Hash] command data
            # @return [String] command class name
            def command_class_name(command)
              return command_group_class(command) if Object.const_defined?(command_group_class(command))
              return command_v2_class(command) if Object.const_defined?(command_v2_class(command))

              command_class(command)
            end

            # Returns the V1 command class name.
            #
            # @param command [Hash] command data
            # @return [String] command class name
            def command_class(command)
              "#{command[:context]}::Commands::#{command[:subject]}::#{command[:command]}"
            end

            # Returns the V2 command class name.
            #
            # @param command [Hash] command data
            # @return [String] command class name
            def command_v2_class(command)
              "#{command[:context]}::#{command[:subject]}::Commands::#{command[:command]}::Command"
            end

            # Returns the command group class name.
            #
            # @param command [Hash] command data
            # @return [String] command group class name
            def command_group_class(command)
              "CommandGroups::#{command[:command]}::Command"
            end
          end
        end
      end
    end
  end
end
