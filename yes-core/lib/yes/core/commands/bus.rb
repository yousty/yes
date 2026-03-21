# frozen_string_literal: true

module Yes
  module Core
    module Commands
      class Bus
        include Yes::Core::OpenTelemetry::Trackable

        attr_reader :command_processor, :perform_inline
        private :command_processor, :perform_inline

        def initialize(
          command_processor: Processor,
          perform_inline: Yes::Core.configuration.process_commands_inline
        )
          @command_processor = command_processor
          @perform_inline = perform_inline
        end

        # Passees commands on to the command processor, in case origin is not provided,
        # it will be derived from the caller. Also decides based on config whether to perform commands inline or not
        # @param command_or_commands [Command, Array<Command>] Command(s) instance(s)
        # @param origin [String] Origin of the command
        # @param notifier_options [Hash] Options for command notifier
        # @param batch_id [String] Batch ID
        # @return [void]
        def call(
          command_or_commands,
          origin: nil,
          notifier_options: {},
          batch_id: nil
        )
          origin ||= Utils::CallerUtils.origin_from_caller(caller_locations(1..1).first)

          perform_method = perform_inline ? :perform_now : :perform_later
          self.class.current_span&.add_attributes({ perform_method: perform_method.to_s, origin: }.stringify_keys)

          command_processor.public_send(
            perform_method, origin, command_or_commands, notifier_options, batch_id, perform_inline
          )
        end
        otl_trackable :call, Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Command Bus Schedule')
      end
    end
  end
end
