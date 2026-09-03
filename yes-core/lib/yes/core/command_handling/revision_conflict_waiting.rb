# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Shared by {CommandExecutor} and {CommandGroupExecutor}: the wait between two
      # attempts after a PgEventstore::WrongExpectedRevisionError. Expects the
      # including class to expose a private +aggregate+ reader.
      module RevisionConflictWaiting
        private

        # Sleeps only while the read model has not yet caught up with the stream
        # revision reported by the conflict, see {RevisionConflictBackoff}.
        #
        # @param error [PgEventstore::WrongExpectedRevisionError]
        # @param attempt [Integer] the 1-based retry attempt about to be made
        # @return [void]
        def wait_for_read_model(error, attempt)
          delay = RevisionConflictBackoff.delay(
            error:, aggregate_id: aggregate.id, read_model_revision: current_read_model_revision, attempt:
          )
          sleep(delay) if delay.positive?
        end

        # @return [Integer, nil] the freshly reloaded read model revision; nil without a read model or
        #   when the row disappeared underneath the retry, both of which mean "retry immediately"
        def current_read_model_revision
          return nil unless aggregate.class.read_model_enabled?

          aggregate.reload.revision
        rescue ActiveRecord::RecordNotFound
          nil
        end
      end
    end
  end
end
