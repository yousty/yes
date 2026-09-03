# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Decides how long an executor waits before retrying a command after a
      # PgEventstore::WrongExpectedRevisionError.
      #
      # The executors derive the expected revision from the read model's revision
      # column. When the conflicting append came from this service, the read model
      # was updated in the same process, so the very next attempt already sees the
      # new revision and any wait only adds latency. When another service appended
      # to the stream, the column only advances once this service's event listener
      # has projected that event, typically a few hundred milliseconds later.
      # Retrying immediately then burns every attempt inside the same half second
      # and the command surfaces as a 500.
      #
      # The error carries the stream's actual revision, so for the aggregate's own
      # stream the two cases can be told apart: retry at once while the reloaded
      # read model has caught up, back off while it is still behind. A conflict on
      # an external aggregate's stream (see EventPublisher#verify_external_revisions!)
      # cannot be checked here and always backs off.
      #
      # Delays follow the same 10 ms doubling schedule as the ConcurrentUpdateError
      # branch, capped per attempt and in total, with jitter so that requests which
      # collided once do not retry in lockstep.
      class RevisionConflictBackoff
        # @return [Float] delay of the first waiting attempt, in seconds
        BASE_DELAY_SECONDS = 0.01
        # @return [Float] longest delay of a single attempt, in seconds
        MAX_DELAY_SECONDS = 1.0
        # @return [Float] total sleep budget across all retries of one command, in seconds
        TOTAL_BUDGET_SECONDS = 2.0
        # @return [Float] fraction by which a delay is randomised in both directions
        JITTER_FRACTION = 0.25

        class << self
          # @param error [PgEventstore::WrongExpectedRevisionError] the conflict that was raised
          # @param aggregate_id [String] id of the aggregate the executor works on; used to tell its own
          #   stream from an external aggregate's stream
          # @param read_model_revision [Integer, nil] the revision the read model reports after a
          #   reload, or nil when the aggregate has no read model
          # @param attempt [Integer] the 1-based retry attempt about to be made
          # @return [Float] seconds to wait before retrying, 0.0 to retry immediately
          def delay(error:, aggregate_id:, read_model_revision:, attempt:)
            return 0.0 unless worth_waiting?(error, aggregate_id, read_model_revision)

            remaining = TOTAL_BUDGET_SECONDS - waited_before(attempt)
            return 0.0 unless remaining.positive?

            jittered([schedule(attempt), remaining].min)
          end

          # The undisturbed exponential schedule, shared with the ConcurrentUpdateError retries.
          #
          # @param attempt [Integer] the 1-based retry attempt
          # @return [Float] seconds
          def schedule(attempt)
            [BASE_DELAY_SECONDS * (2**(attempt - 1)), MAX_DELAY_SECONDS].min
          end

          private

          # @return [Boolean] false only when the conflict is on the aggregate's own stream and the
          #   read model already reports at least the stream revision the conflict was raised with
          def worth_waiting?(error, aggregate_id, read_model_revision)
            return true unless own_stream?(error.stream, aggregate_id)
            return false unless read_model_revision.is_a?(Integer) && error.revision.is_a?(Integer)

            read_model_revision < error.revision
          end

          # @return [Boolean] true when the stream belongs to the aggregate itself; a stream that
          #   cannot be inspected is treated as the aggregate's own
          def own_stream?(stream, aggregate_id)
            return true unless stream.respond_to?(:stream_id)

            stream.stream_id.to_s == aggregate_id.to_s
          end

          # @return [Float] seconds already spent sleeping before this attempt
          def waited_before(attempt)
            (1...attempt).sum { schedule(_1) }
          end

          # @return [Float] the delay randomised by ±JITTER_FRACTION
          def jittered(delay)
            delay * (1 + (JITTER_FRACTION * ((2 * rand) - 1)))
          end
        end
      end
    end
  end
end
