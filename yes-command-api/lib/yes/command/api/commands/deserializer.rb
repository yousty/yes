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

            # Resolves the command class name, trying (in order):
            #   1. legacy top-level command group: `CommandGroups::<Name>::Command`
            #   2. aggregate-DSL command group: `<Ctx>::<Subj>::CommandGroups::<Name>::Command`
            #   3. V2 command:                   `<Ctx>::<Subj>::Commands::<Name>::Command`
            #   4. V1 command:                   `<Ctx>::Commands::<Subj>::<Name>`
            #
            # @param command [Hash] command data
            # @return [String] command class name
            def command_class_name(command)
              [
                command_group_class(command),
                command_group_v2_class(command),
                command_v2_class(command),
                command_class(command)
              ].each do |name|
                Kernel.const_get(name)
                return name
              rescue NameError
                next
              end
              # None found — return V2 name so const_get in caller raises NameError
              command_v2_class(command)
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

            # Returns the legacy top-level command group class name (used by
            # stateless cross-aggregate groups).
            #
            # @param command [Hash] command data
            # @return [String] command group class name
            def command_group_class(command)
              "CommandGroups::#{command[:command]}::Command"
            end

            # Returns the aggregate-DSL command group class name (generated
            # by the `command_group` macro inside an aggregate body).
            #
            # @param command [Hash] command data
            # @return [String] command group class name
            def command_group_v2_class(command)
              "#{command[:context]}::#{command[:subject]}::CommandGroups::#{command[:command]}::Command"
            end
          end
        end
      end
    end
  end
end
