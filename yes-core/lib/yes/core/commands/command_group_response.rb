# frozen_string_literal: true

module Yes
  module Core
    module Commands
      # Response returned by {Yes::Core::CommandHandling::CommandGroupHandler}.
      #
      # Mirrors the surface of {Yes::Core::Commands::Response} (success?,
      # error_details, type, to_notification) but carries an array of
      # published events instead of a single one — one per sub-command in the
      # group.
      class CommandGroupResponse < Dry::Struct
        attribute :cmd, Yes::Core::Types.Instance(Yes::Core::Commands::CommandGroup)
        attribute :events,
                  Yes::Core::Types::Array.of(
                    Yes::Core::Types.Instance(PgEventstore::Event)
                  ).default([].freeze)
        attribute? :error,
                   Yes::Core::Types.Instance(Yes::Core::CommandHandling::GuardEvaluator::TransitionError).
                     optional

        delegate :transaction, :batch_id, :payload, :metadata, to: :cmd

        # @return [Boolean] true when no error is attached
        def success?
          error.blank?
        end

        # @return [Hash] structured error info, or empty when successful
        def error_details
          return {} unless error

          {
            message: error.message,
            type: error.message&.underscore&.tr(' ', '_'),
            extra: (error.extra if error.respond_to?(:extra) && error.extra.present?)
          }.compact
        end

        # @return [String] the response type tag
        def type
          success? ? 'command_success' : 'command_error'
        end

        # @return [Hash] notification-shaped hash for downstream consumers
        def to_notification
          error_payload = success? ? {} : { error_details: }
          {
            type:,
            batch_id:,
            payload:,
            metadata:,
            command: cmd.class.name,
            id: cmd.command_id,
            transaction: transaction.to_h
          }.merge(error_payload)
        end

        # @return [Hash] JSON-friendly representation
        def as_json(*)
          to_notification.as_json
        end
      end
    end
  end
end
