# frozen_string_literal: true

module Yes
  module Core
    module Jobs
      # Background job that runs periodically to recover stuck read models
      # This job should be scheduled to run every 30 seconds via cron or similar
      class ReadModelRecoveryJob < ActiveJob::Base
        # Circuit breaker configuration
        MAX_CONSECUTIVE_FAILURES = 5
        CIRCUIT_BREAKER_TIMEOUT = 5.minutes
        
        queue_as :critical

        class << self
          # Track circuit breaker state in memory (or Redis in production)
          attr_accessor :consecutive_failures, :circuit_opened_at
        end

        self.consecutive_failures = 0
        self.circuit_opened_at = nil

        # Performs the recovery of stuck read models
        # @param stuck_timeout [Integer] Minutes after which a model is considered stuck (default: 1)
        # @param batch_size [Integer] Number of read models to process at once (default: 100)
        def perform(stuck_timeout_minutes: 1, batch_size: 100)
          # Check circuit breaker
          if circuit_open?
            Rails.logger.warn("ReadModelRecoveryJob circuit breaker is open, skipping execution")
            return
          end

          stuck_timeout = stuck_timeout_minutes.minutes
          
          Rails.logger.info("Starting read model recovery scan (timeout: #{stuck_timeout_minutes} minutes)")
          
          results = Yes::Core::CommandHandling::ReadModelRecoveryService.recover_all_stuck_read_models(
            stuck_timeout:,
            batch_size:
          )
          
          process_results(results)
          
          # Reset circuit breaker on success
          self.class.consecutive_failures = 0
          
          Rails.logger.info("Read model recovery scan completed: #{results.size} models processed")
        rescue ActiveRecord::ActiveRecordError => e
          # Database-related errors (connection issues, deadlocks, etc.)
          Rails.logger.error("Database error during read model recovery: #{e.message}")
          handle_job_failure(e)
          raise
        rescue PgEventstore::Error => e
          # Event store related errors (revision conflicts, stream errors)
          Rails.logger.error("Event store error during read model recovery: #{e.message}")
          handle_job_failure(e)
          raise
        rescue NameError, NoMethodError => e
          # Configuration or class loading errors - these should not trigger circuit breaker
          Rails.logger.error("Configuration error during read model recovery: #{e.message}")
          Rails.logger.error("This likely indicates a misconfiguration - please check your read model classes")
          # Don't increment circuit breaker for configuration errors
          raise
        rescue => e
          # Unexpected errors - log with full backtrace for debugging
          Rails.logger.error("Unexpected error during read model recovery: #{e.class.name} - #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          
          # Still handle as a failure for circuit breaker
          handle_job_failure(e)
          
          # Re-raise to ensure job framework knows it failed
          raise
        end

        private

        # Processes the recovery results and tracks metrics
        # @param results [Array<RecoveryResult>] The recovery results
        def process_results(results)
          successful = results.count(&:success)
          failed = results.count { |r| !r.success }
          
          if failed > 0
            Rails.logger.warn("Read model recovery had #{failed} failures out of #{results.size} attempts")
            
            # Send alert if too many failures
            if failed > results.size / 2
              alert_on_high_failure_rate(failed, results.size)
            end
          end
          
          # Track metrics (integrate with your monitoring solution)
          track_metrics(successful:, failed:)
          
          # Alert on models stuck for too long
          check_for_long_stuck_models
        end

        # Checks if circuit breaker is open
        # @return [Boolean] True if circuit is open
        def circuit_open?
          return false unless self.class.circuit_opened_at
          
          if Time.current - self.class.circuit_opened_at > CIRCUIT_BREAKER_TIMEOUT
            Rails.logger.info("ReadModelRecoveryJob circuit breaker timeout expired, resetting")
            self.class.circuit_opened_at = nil
            self.class.consecutive_failures = 0
            false
          else
            true
          end
        end

        # Handles job failure and manages circuit breaker
        # @param error [Exception] The error that occurred
        def handle_job_failure(error)
          self.class.consecutive_failures += 1
          
          Rails.logger.error(
            "ReadModelRecoveryJob failed (attempt #{self.class.consecutive_failures}): #{error.message}"
          )
          
          if self.class.consecutive_failures >= MAX_CONSECUTIVE_FAILURES
            self.class.circuit_opened_at = Time.current
            Rails.logger.error(
              "ReadModelRecoveryJob circuit breaker opened after #{MAX_CONSECUTIVE_FAILURES} consecutive failures"
            )
            
            # Send critical alert
            alert_on_circuit_breaker_open
          end
        end

        # Checks for models that have been stuck for too long
        def check_for_long_stuck_models
          critical_timeout = 5.minutes
          
          # Find models stuck for more than critical timeout
          long_stuck_models = find_long_stuck_models(critical_timeout)
          
          if long_stuck_models.any?
            alert_on_long_stuck_models(long_stuck_models)
          end
        end

        # Finds read models stuck for longer than the specified timeout
        # @param timeout [ActiveSupport::Duration] The timeout duration
        # @return [Array<ActiveRecord::Base>] Long stuck models
        def find_long_stuck_models(timeout)
          models = []
          
          read_model_classes.each do |model_class|
            next unless model_class.column_names.include?('pending_update_since')
            
            models.concat(
              model_class
                .where.not(pending_update_since: nil)
                .where('pending_update_since < ?', timeout.ago)
                .to_a
            )
          end
          
          models
        end

        # Gets all read model classes from configuration
        # @return [Array<Class>] Read model classes
        def read_model_classes
          Yes::Core.configuration.all_read_model_classes
        end

        # Tracks metrics (implement based on your monitoring solution)
        # @param successful [Integer] Number of successful recoveries
        # @param failed [Integer] Number of failed recoveries
        def track_metrics(successful:, failed:)
          # Example for StatsD/DataDog
          # StatsD.gauge('read_model_recovery.successful', successful)
          # StatsD.gauge('read_model_recovery.failed', failed)
          
          # Example for Prometheus
          # Prometheus.gauge(:read_model_recovery_successful, successful)
          # Prometheus.gauge(:read_model_recovery_failed, failed)
          
          Rails.logger.info("Recovery metrics - Successful: #{successful}, Failed: #{failed}")
        end

        # Sends alert on high failure rate
        # @param failed [Integer] Number of failures
        # @param total [Integer] Total attempts
        def alert_on_high_failure_rate(failed, total)
          message = "High read model recovery failure rate: #{failed}/#{total} attempts failed"
          Rails.logger.error(message)
          
          # Implement your alerting mechanism here
          # Example: Sentry.capture_message(message, level: :error)
          # Example: Slack.notify(message, channel: '#alerts')
        end

        # Sends alert when circuit breaker opens
        def alert_on_circuit_breaker_open
          message = "ReadModelRecoveryJob circuit breaker opened - job execution suspended"
          Rails.logger.error(message)
          
          # Implement critical alerting here
          # Example: PagerDuty.trigger(message)
        end

        # Sends alert for long stuck models
        # @param models [Array<ActiveRecord::Base>] The stuck models
        def alert_on_long_stuck_models(models)
          message = "#{models.size} read models stuck for > 5 minutes: " \
                   "#{models.map { |m| "#{m.class.name}##{m.id}" }.join(', ')}"
          Rails.logger.error(message)
          
          # Implement critical alerting here
        end
      end
    end
  end
end