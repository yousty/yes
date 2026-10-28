# frozen_string_literal: true

module Dummy
  # Command notifier that records every notification it receives. It has a constant name so that it can be
  # passed to the command processor by name, as a per-call notifier is.
  class RecordingNotifier < Yes::Core::Commands::Notifier
    class << self
      # @return [Array<Array>] notifications received by all instances, as [method_name, *arguments]
      def notifications
        @notifications ||= []
      end

      # Forgets the recorded notifications
      # @return [void]
      def reset!
        notifications.clear
      end
    end

    # @return [Hash] the options the notifier was instantiated with
    attr_reader :options

    # @param options [Hash] notifier options
    def initialize(options = {})
      super
      @options = options
    end

    def notify_batch_started(batch_id, _transaction = nil, commands = nil)
      self.class.notifications << [:batch_started, batch_id, commands]
    end

    def notify_batch_finished(batch_id, _transaction = nil, responses = nil)
      self.class.notifications << [:batch_finished, batch_id, responses]
    end

    def notify_command_response(cmd_response)
      self.class.notifications << [:command_response, cmd_response]
    end
  end
end
