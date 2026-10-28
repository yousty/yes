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
        # @param extra_notifier_classes [Array<Class>] Notifier classes to run for this call only, in addition
        #   to the configured +command_notifier_classes+. They also run when commands are processed inline.
        # @return [void]
        def call(
          command_or_commands,
          origin: nil,
          notifier_options: {},
          batch_id: nil,
          extra_notifier_classes: []
        )
          origin ||= Utils::CallerUtils.origin_from_caller(caller_locations(1..1).first)

          perform_method = perform_inline ? :perform_now : :perform_later
          self.class.current_span&.add_attributes({ perform_method: perform_method.to_s, origin: }.stringify_keys)

          # The extra argument is only passed when needed: during a rolling deploy an older worker runs jobs
          # enqueued by this code, and a custom processor may still have the 5-argument signature.
          # Only class names are passed, as the processor is an ActiveJob and its arguments must serialize.
          processor_args = [origin, command_or_commands, notifier_options, batch_id, perform_inline]
          processor_args << extra_notifier_classes.map(&:name) if extra_notifier_classes.any?

          command_processor.public_send(perform_method, *processor_args)
        end
        otl_trackable :call, Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Command Bus Schedule')
      end
    end
  end
end
