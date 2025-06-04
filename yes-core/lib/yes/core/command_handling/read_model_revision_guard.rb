# frozen_string_literal: true

require_relative '../utils/exponential_retrier'

module Yes
  module Core
    module CommandHandling
      # Ensures that read model revisions match expected event revisions
      # Uses ExponentialRetrier for retry logic with exponential backoff
      # This handles eventual consistency between the event store and read model databases
      class ReadModelRevisionGuard
        # Error raised when revision guard fails after maximum retries
        class RevisionMismatchError < Yes::Core::Utils::ExponentialRetrier::RetryFailedError; end

        # Error raised when timeout is exceeded
        class TimeoutError < Yes::Core::Utils::ExponentialRetrier::TimeoutError; end

        # Error raised when revision has already been applied
        class RevisionAlreadyAppliedError < StandardError; end

        # Logger wrapper that adds revision context to log messages
        class ContextualLogger
          def initialize(base_logger, context)
            @base_logger = base_logger
            @context = context
          end

          def info(message)
            return unless base_logger

            base_logger.info("#{message} for revision #{context.expected_revision}")
          end

          def error(message)
            return unless base_logger

            base_logger.error(
              "#{message} for revision #{context.expected_revision}. " \
              "Current revision: #{context.current_revision}"
            )
          end

          def debug(message)
            return unless base_logger&.debug?

            base_logger.debug(
              "#{message} for revision #{context.expected_revision} (current: #{context.current_revision})"
            )
          end

          private

          attr_reader :base_logger, :context
        end

        class << self
          # Calls the guard with a read model and expected revision
          #
          # @param read_model [Object] The read model to guard
          # @param expected_revision [Integer] The expected revision (should be read_model.revision + 1)
          # @param revision_column [Symbol] The revision column to use (defaults to :revision)
          # @yield Block to execute when revisions match
          # @return [Object] Result of the block execution
          # @raise [RevisionMismatchError] When revisions don't match after maximum retries
          # @raise [TimeoutError] When timeout is exceeded
          # @raise [RevisionAlreadyAppliedError] When revision has already been applied
          def call(read_model, expected_revision, revision_column: :revision, &)
            new(read_model, expected_revision, revision_column:).call(&)
          end
        end

        # @param read_model [Object] The read model to guard
        # @param expected_revision [Integer] The expected revision
        # @param revision_column [Symbol] The revision column to use (defaults to :revision)
        def initialize(read_model, expected_revision, revision_column: :revision)
          @read_model = read_model
          @expected_revision = expected_revision
          @revision_column = revision_column
        end

        # Gets the expected revision for this guard
        #
        # @return [Integer] The expected revision value
        attr_reader :expected_revision

        # Gets the current revision from the read model using the specified column
        #
        # @return [Integer] The current revision value
        def current_revision
          read_model.public_send(revision_column)
        end

        # Executes the guard logic with retry mechanism
        #
        # @yield Block to execute when revisions match
        # @return [Object] Result of the block execution
        # @raise [RevisionMismatchError] When revisions don't match after maximum retries
        # @raise [TimeoutError] When timeout is exceeded
        # @raise [RevisionAlreadyAppliedError] When revision has already been applied
        def call(&)
          retrier = create_retrier

          begin
            retrier.call(
              condition_check: -> { check_revision_and_return_match_status },
              failure_message: revision_mismatch_message,
              timeout_message: timeout_message,
              &
            )
          rescue Yes::Core::Utils::ExponentialRetrier::RetryFailedError => e
            raise RevisionMismatchError, e.message
          rescue Yes::Core::Utils::ExponentialRetrier::TimeoutError => e
            raise TimeoutError, e.message
          end
        end

        private

        attr_reader :read_model, :revision_column

        # Creates the retrier with custom logging context
        #
        # @return [Yes::Core::Utils::ExponentialRetrier] Configured retrier instance
        def create_retrier
          Yes::Core::Utils::ExponentialRetrier.new(
            max_retries: 6,
            base_sleep_time: 0.1,
            max_sleep_time: 5.0,
            jitter_factor: 0.1,
            timeout: 30,
            logger: create_contextual_logger
          )
        end

        # Creates a logger wrapper that adds revision context to log messages
        #
        # @return [ContextualLogger] Logger with revision context
        def create_contextual_logger
          base_logger = defined?(Rails.logger) ? Rails.logger : nil
          ContextualLogger.new(base_logger, self)
        end

        # Checks revision status and returns whether revision matches
        # Also handles the revision already applied error
        #
        # @return [Boolean] True if revision matches
        # @raise [RevisionAlreadyAppliedError] When revision has already been applied
        def check_revision_and_return_match_status
          read_model.reload
          check_revision_status!
          revision_matches?
        end

        # Checks if the current read model revision + 1 equals the expected revision
        #
        # @return [Boolean] True if revisions match
        def revision_matches?
          read_model.public_send(revision_column) + 1 == expected_revision
        end

        # Checks if we've somehow skipped past the expected revision
        #
        # @raise [RevisionAlreadyAppliedError] When revision has already been applied
        def check_revision_status!
          return unless current_revision >= expected_revision

          raise RevisionAlreadyAppliedError,
                "Expected revision #{expected_revision} but read model already at revision #{current_revision}. " \
                'This revision may have already been applied.'
        end

        # Generates error message for revision mismatch
        #
        # @return [String] Error message
        def revision_mismatch_message
          'Revision mismatch. ' \
            "Expected revision #{expected_revision}, but read model has revision #{current_revision}. " \
            "Expected: read_model.#{revision_column} (#{current_revision}) + 1 = #{expected_revision}"
        end

        # Generates error message for timeout
        #
        # @return [String] Timeout message
        def timeout_message
          "Timeout waiting for revision #{expected_revision}. Current revision: #{current_revision}"
        end
      end
    end
  end
end
