# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Ensures that read model revisions match expected event revisions
      # Retries with exponential backoff if revisions don't match
      # This handles eventual consistency between the event store and read model databases
      class ReadModelRevisionGuard
        # Maximum number of retry attempts
        MAX_RETRIES = 6

        # Base sleep time in seconds for exponential backoff
        BASE_SLEEP_TIME = 0.1

        # Maximum sleep time to prevent excessive waiting
        MAX_SLEEP_TIME = 5.0

        # Jitter factor for randomizing sleep times (±10%)
        JITTER_FACTOR = 0.1

        # Maximum time to wait for revision match before timing out
        TIMEOUT = 30

        # Error raised when revision guard fails after maximum retries
        class RevisionMismatchError < StandardError; end

        # Error raised when timeout is exceeded
        class TimeoutError < StandardError; end

        # Error raised when revision has already been applied
        class RevisionAlreadyAppliedError < StandardError; end

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
          @start_time = Time.current
        end

        # Executes the guard logic with retry mechanism
        #
        # @yield Block to execute when revisions match
        # @return [Object] Result of the block execution
        # @raise [RevisionMismatchError] When revisions don't match after maximum retries
        # @raise [TimeoutError] When timeout is exceeded
        # @raise [RevisionAlreadyAppliedError] When revision has already been applied
        def call(&)
          attempts = 0
          total_wait_time = 0

          loop do
            check_timeout!
            check_revision_status!

            if revision_matches?
              log_success(attempts, total_wait_time) if attempts.positive?
              return yield
            end

            attempts += 1
            if attempts > MAX_RETRIES
              log_failure(attempts, total_wait_time)
              raise RevisionMismatchError, revision_mismatch_message(attempts)
            end

            sleep_time = sleep_and_reload(attempts)
            total_wait_time += sleep_time
          end
        end

        private

        attr_reader :read_model, :expected_revision, :revision_column, :start_time

        # Gets the current revision from the read model using the specified column
        #
        # @return [Integer] The current revision value
        def current_revision
          read_model.public_send(revision_column)
        end

        # Checks if the current read model revision + 1 equals the expected revision
        #
        # @return [Boolean] True if revisions match
        def revision_matches?
          current_revision + 1 == expected_revision
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

        # Checks if the timeout has been exceeded
        #
        # @raise [TimeoutError] When timeout is exceeded
        def check_timeout!
          elapsed_time = Time.current - start_time

          return unless elapsed_time > TIMEOUT

          raise TimeoutError,
                "Timeout after #{elapsed_time.round(2)}s waiting for revision #{expected_revision}. " \
                "Current revision: #{current_revision}"
        end

        # Sleeps with exponential backoff and jitter, then reloads the read model
        #
        # @param attempt_number [Integer] Current attempt number
        # @return [Float] The actual sleep time used
        def sleep_and_reload(attempt_number)
          sleep_time = calculate_sleep_time(attempt_number)
          log_retry(attempt_number, sleep_time)
          sleep(sleep_time)
          read_model.reload
          sleep_time
        end

        # Calculates sleep time with exponential backoff, jitter, and maximum cap
        #
        # @param attempt_number [Integer] Current attempt number
        # @return [Float] Sleep time in seconds
        def calculate_sleep_time(attempt_number)
          # Calculate base exponential backoff
          base_sleep = BASE_SLEEP_TIME * (2**(attempt_number - 1))

          # Add jitter (±JITTER_FACTOR) to prevent thundering herd
          jitter = base_sleep * JITTER_FACTOR * rand(-1.0..1.0)
          sleep_with_jitter = base_sleep + jitter

          # Cap at maximum sleep time
          [sleep_with_jitter, MAX_SLEEP_TIME].min
        end

        # Generates error message for revision mismatch
        #
        # @param attempts [Integer] Number of attempts made
        # @return [String] Error message
        def revision_mismatch_message(attempts)
          "Revision mismatch after #{attempts} attempts. " \
            "Expected revision #{expected_revision}, but read model has revision #{current_revision}. " \
            "Expected: read_model.#{revision_column} (#{current_revision}) + 1 = #{expected_revision}"
        end

        # Logs successful revision match after retries
        #
        # @param attempts [Integer] Number of attempts made
        # @param total_wait_time [Float] Total time spent waiting
        # @return [void]
        def log_success(attempts, total_wait_time)
          return unless defined?(Rails.logger)

          Rails.logger.info(
            "ReadModelRevisionGuard succeeded after #{attempts} attempts " \
            "(waited #{total_wait_time.round(2)}s) for revision #{expected_revision}"
          )
        end

        # Logs failure to match revision
        #
        # @param attempts [Integer] Number of attempts made
        # @param total_wait_time [Float] Total time spent waiting
        # @return [void]
        def log_failure(attempts, total_wait_time)
          return unless defined?(Rails.logger)

          Rails.logger.error(
            "ReadModelRevisionGuard failed after #{attempts} attempts " \
            "(waited #{total_wait_time.round(2)}s) for revision #{expected_revision}. " \
            "Current revision: #{current_revision}"
          )
        end

        # Logs retry attempt
        #
        # @param attempt_number [Integer] Current attempt number
        # @param sleep_time [Float] Time to sleep before retry
        # @return [void]
        def log_retry(attempt_number, sleep_time)
          return unless defined?(Rails.logger) && Rails.logger.debug?

          Rails.logger.debug do
            "ReadModelRevisionGuard retry #{attempt_number}/#{MAX_RETRIES} " \
              "for revision #{expected_revision} (current: #{current_revision}). " \
              "Sleeping #{sleep_time.round(3)}s"
          end
        end
      end
    end
  end
end
