# frozen_string_literal: true

module Yes
  module Core
    module Commands
      class Response < Dry::Struct
        attribute :cmd, Yes::Core::Types.Instance(Command)
        attribute? :event, Yes::Core::Types.Instance(PgEventstore::Event).optional
        attribute? :error,
                   Yes::Core::Types.Instance(Yes::Core::CommandHandling::GuardEvaluator::TransitionError).
                     optional

        # @return [TransactionDetails, nil] command's transaction info if present
        #
        delegate :transaction, :batch_id, :payload, :metadata, to: :cmd

        # @return [Boolean] true in case the command was processed successfully
        #
        def success?
          error.blank?
        end

        # @return [Hash] error details in case an error occurred
        #
        def error_details
          return {} unless error

          {
            message: error.message,
            type: error.message&.underscore&.tr(' ', '_'),
            extra: (error.extra if error.respond_to?(:extra) && error.extra.present?)
          }.compact
        end

        # @return [String] type of the command response
        #
        def type
          success? ? 'command_success' : 'command_error'
        end

        # @return [Hash] command response as a hash
        #
        def to_notification
          error = success? ? {} : { error_details: }
          {
            type:,
            batch_id:,
            payload:,
            metadata:,
            command: cmd.class.name,
            id: cmd.command_id,
            transaction: transaction.to_h
          }.merge(error)
        end

        # @return [Hash]
        def as_json(*)
          to_notification.as_json
        end
      end
    end
  end
end
