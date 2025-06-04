# frozen_string_literal: true

module Yes
  module Core
    module Utils
      # Generic exponential backoff retry utility
      # Provides configurable retry logic with exponential backoff, jitter, and timeout
      class ExponentialRetrier
        # Default configuration constants
        DEFAULT_MAX_RETRIES = 6
        DEFAULT_BASE_SLEEP_TIME = 0.1
        DEFAULT_MAX_SLEEP_TIME = 5.0
        DEFAULT_JITTER_FACTOR = 0.1
        DEFAULT_TIMEOUT = 30

        # Error raised when retry fails after maximum attempts
        class RetryFailedError < StandardError; end

        # Error raised when timeout is exceeded
        class TimeoutError < StandardError; end

        # Configuration for the retrier
        #
        # @param max_retries [Integer] Maximum number of retry attempts
        # @param base_sleep_time [Float] Base sleep time in seconds for exponential backoff
        # @param max_sleep_time [Float] Maximum sleep time to prevent excessive waiting
        # @param jitter_factor [Float] Jitter factor for randomizing sleep times
        # @param timeout [Integer] Maximum time to wait before timing out
        # @param logger [Object] Logger instance for retry information
        def initialize(
          max_retries: DEFAULT_MAX_RETRIES,
          base_sleep_time: DEFAULT_BASE_SLEEP_TIME,
          max_sleep_time: DEFAULT_MAX_SLEEP_TIME,
          jitter_factor: DEFAULT_JITTER_FACTOR,
          timeout: DEFAULT_TIMEOUT,
          logger: nil
        )
          @max_retries = max_retries
          @base_sleep_time = base_sleep_time
          @max_sleep_time = max_sleep_time
          @jitter_factor = jitter_factor
          @timeout = timeout
          @logger = logger || (defined?(Rails) ? Rails.logger : nil)
          @start_time = Time.current
        end

        # Executes the retry logic with exponential backoff
        #
        # @param condition_check [Proc] Block that returns true when condition is met
        # @param action [Proc] Block to execute when condition is met
        # @param failure_message [String] Custom failure message for RetryFailedError
        # @param timeout_message [String] Custom timeout message for TimeoutError
        # @yield Alternative to action parameter - block to execute when condition is met
        # @return [Object] Result of the action/block execution
        # @raise [RetryFailedError] When condition is not met after maximum retries
        # @raise [TimeoutError] When timeout is exceeded
        def call(condition_check:, action: nil, failure_message: nil, timeout_message: nil, &block)
          action_block = action || block
          raise ArgumentError, 'Either action parameter or block must be provided' unless action_block

          attempts = 0
          total_wait_time = 0

          loop do
            check_timeout!(timeout_message)

            if condition_check.call
              log_success(attempts, total_wait_time) if attempts.positive?
              return action_block.call
            end

            attempts += 1
            if attempts >= max_retries
              log_failure(attempts, total_wait_time)
              raise RetryFailedError, failure_message || default_failure_message(attempts)
            end

            sleep_time = sleep_with_backoff(attempts)
            total_wait_time += sleep_time
          end
        end

        private

        attr_reader :max_retries, :base_sleep_time, :max_sleep_time, :jitter_factor,
                    :timeout, :logger, :start_time

        # Checks if the timeout has been exceeded
        #
        # @param custom_message [String] Custom timeout message
        # @raise [TimeoutError] When timeout is exceeded
        def check_timeout!(custom_message = nil)
          elapsed_time = Time.current - start_time

          return unless elapsed_time > timeout

          message = custom_message || "Timeout after #{elapsed_time.round(2)}s"
          raise TimeoutError, message
        end

        # Sleeps with exponential backoff and jitter
        #
        # @param attempt_number [Integer] Current attempt number
        # @return [Float] The actual sleep time used
        def sleep_with_backoff(attempt_number)
          sleep_time = calculate_sleep_time(attempt_number)
          log_retry(attempt_number, sleep_time)
          sleep(sleep_time)
          sleep_time
        end

        # Calculates sleep time with exponential backoff, jitter, and maximum cap
        #
        # @param attempt_number [Integer] Current attempt number
        # @return [Float] Sleep time in seconds
        def calculate_sleep_time(attempt_number)
          # Calculate base exponential backoff
          base_sleep = base_sleep_time * (2**(attempt_number - 1))

          # Add jitter to prevent thundering herd
          jitter = base_sleep * jitter_factor * rand(-1.0..1.0)
          sleep_with_jitter = base_sleep + jitter

          # Cap at maximum sleep time
          [sleep_with_jitter, max_sleep_time].min
        end

        # Default failure message when none is provided
        #
        # @param attempts [Integer] Number of attempts made
        # @return [String] Default failure message
        def default_failure_message(attempts)
          "Retry failed after #{attempts} attempts"
        end

        # Logs successful retry after multiple attempts
        #
        # @param attempts [Integer] Number of attempts made
        # @param total_wait_time [Float] Total time spent waiting
        # @return [void]
        def log_success(attempts, total_wait_time)
          return unless logger

          logger.info(
            "ExponentialRetrier succeeded after #{attempts} attempts " \
            "(waited #{total_wait_time.round(2)}s)"
          )
        end

        # Logs failure after maximum retries
        #
        # @param attempts [Integer] Number of attempts made
        # @param total_wait_time [Float] Total time spent waiting
        # @return [void]
        def log_failure(attempts, total_wait_time)
          return unless logger

          logger.error(
            "ExponentialRetrier failed after #{attempts} attempts " \
            "(waited #{total_wait_time.round(2)}s)"
          )
        end

        # Logs retry attempt
        #
        # @param attempt_number [Integer] Current attempt number
        # @param sleep_time [Float] Time to sleep before retry
        # @return [void]
        def log_retry(attempt_number, sleep_time)
          return unless logger&.debug?

          logger.debug(
            "ExponentialRetrier retry #{attempt_number}/#{max_retries}. " \
            "Sleeping #{sleep_time.round(3)}s"
          )
        end
      end
    end
  end
end
