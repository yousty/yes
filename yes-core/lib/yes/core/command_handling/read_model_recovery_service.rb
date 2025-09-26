# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Service for recovering read models that are stuck in pending state
      # This handles cases where the process was interrupted after publishing an event
      # but before updating the read model
      class ReadModelRecoveryService
        # Default timeout after which a read model is considered stuck
        DEFAULT_STUCK_TIMEOUT = 1.minute

        # Recovery attempt result
        RecoveryResult = Struct.new(:success, :read_model, :error_message, keyword_init: true)

        class << self
          include Yousty::Eventsourcing::OpenTelemetry::Trackable
          # Finds and recovers all stuck read models
          # @param stuck_timeout [ActiveSupport::Duration] Time after which a model is considered stuck
          # @param batch_size [Integer] Number of read models to process at once
          # @return [Array<RecoveryResult>] Results of recovery attempts
          def recover_all_stuck_read_models(stuck_timeout: DEFAULT_STUCK_TIMEOUT, batch_size: 100)
            results = []
            
            find_stuck_read_models_with_aggregates(stuck_timeout:, batch_size:).each do |entry|
              result = recover_read_model(
                entry[:read_model], 
                aggregate_class: entry[:aggregate_class],
                is_draft: entry[:is_draft]
              )
              results << result
              
              log_recovery_result(result)
            end
            
            results
          end

          # Recovers a single read model
          # @param read_model [ActiveRecord::Base] The read model to recover
          # @param aggregate_class [Class] The aggregate class to use for recovery
          # @param is_draft [Boolean] Flag indicating if this is a draft aggregate
          # @return [RecoveryResult] Result of the recovery attempt
          def recover_read_model(read_model, aggregate_class:, is_draft: false)
            # Use advisory lock to prevent concurrent recovery attempts
            lock_key = "read_model_recovery_#{read_model.class.name}_#{read_model.id}"
            
            with_advisory_lock(lock_key) do
              # Re-check if still stuck after acquiring lock
              read_model.reload

              unless read_model.pending_update_since?
                return RecoveryResult.new(success: true, read_model:, error_message: 'Already recovered')
              end
              
              # Instantiate aggregate with proper parameters
              aggregate_id = determine_aggregate_id(read_model)
              
              aggregate = if is_draft
                            aggregate_class.new(aggregate_id, draft: true)
                          else
                            aggregate_class.new(aggregate_id)
                          end
              
              latest_event = aggregate.latest_event
              
              # Reapply the update using ReadModelUpdater
              updater = ReadModelUpdater.new(aggregate)
              updater.call(latest_event, latest_event.data)
              
              RecoveryResult.new(success: true, read_model:)
            end
          rescue ActiveRecord::ActiveRecordError => e
            # Database errors during recovery
            RecoveryResult.new(
              success: false,
              read_model:,
              error_message: "Database error during recovery: #{e.message}"
            )
          rescue PgEventstore::Error => e
            # Event store errors during recovery
            RecoveryResult.new(
              success: false,
              read_model:,
              error_message: "Event store error during recovery: #{e.message}"
            )
          rescue => e
            # Unexpected errors - log them for debugging
            Rails.logger.error("Unexpected error recovering read model #{read_model.class.name}##{read_model.id}: #{e.class.name}")
            RecoveryResult.new(
              success: false,
              read_model:,
              error_message: "Unexpected error: #{e.class.name} - #{e.message}"
            )
          end

          # Checks if a read model needs recovery and attempts it with retries
          # @param read_model [ActiveRecord::Base] The read model to check
          # @param aggregate [Yes::Core::Aggregate] Aggregate instance to use for recovery
          # @param threshold [ActiveSupport::Duration] Time threshold for recovery (default: 5 seconds)
          # @param max_retries [Integer] Maximum number of retry attempts (default: 3)
          # @return [void]
          def check_and_recover_with_retries(read_model, aggregate:, threshold: 5.seconds, max_retries: 3)
            return unless read_model.respond_to?(:pending_update_since)
            
            retrier = Yes::Core::Utils::ExponentialRetrier.new(
              max_retries: max_retries,
              base_sleep_time: 0.1,
              max_sleep_time: 1.0,
              timeout: 5,
              logger: Rails.logger
            )
            
            begin
              retrier.call(
                condition_check: -> { attempt_recovery_if_pending(read_model, threshold, aggregate:) },
                failure_message: "Could not recover pending read model #{read_model.class.name}##{read_model.id}",
                timeout_message: "Timeout waiting for read model recovery #{read_model.class.name}##{read_model.id}"
              ) do
                # Success - either not pending or recovered
                true
              end
            rescue Yes::Core::Utils::ExponentialRetrier::RetryFailedError,
                   Yes::Core::Utils::ExponentialRetrier::TimeoutError => e
              # Log warning but continue - background job will handle it
              Rails.logger.warn(e.message)
            end
          end

          otl_trackable(
            :check_and_recover_with_retries,
            Yousty::Eventsourcing::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Check and Recover Readmodel with Retries')
          )

          private

          # Checks state and attempts recovery in one go
          # @param read_model [ActiveRecord::Base] The read model to check
          # @param threshold [ActiveSupport::Duration] Time threshold for recovery
          # @param aggregate [Yes::Core::Aggregate] Aggregate instance to use for recovery
          # @return [Boolean] True if no recovery needed or recovery succeeded, false if recovery needed but failed
          def attempt_recovery_if_pending(read_model, threshold, aggregate:)
            read_model.reload
            
            # Not pending - we're good
            return true unless read_model.pending_update_since.present?
            
            # Pending but too recent - don't attempt recovery yet
            return true unless read_model.pending_update_since < threshold.ago
            
            # Pending and old enough - attempt recovery now
            Rails.logger.info("Read model #{read_model.class.name}##{read_model.id} is in pending state, attempting recovery")

            begin
              updater = ReadModelUpdater.new(aggregate)
              updater.call(
                aggregate.latest_event,
                aggregate.latest_event.data
              )
              Rails.logger.info("Successfully recovered read model #{read_model.class.name}##{read_model.id}")
              true
            rescue ActiveRecord::ActiveRecordError, PgEventstore::Error => e
              # Expected errors during recovery
              Rails.logger.debug("Recovery attempt failed for #{read_model.class.name}##{read_model.id}: #{e.message}")
              false
            rescue => e
              # Unexpected errors
              Rails.logger.error("Unexpected error during recovery attempt for #{read_model.class.name}##{read_model.id}: #{e.class.name} - #{e.message}")
              false
            end
          end

          # Finds all read models stuck in pending state with their aggregate classes
          # @param stuck_timeout [ActiveSupport::Duration] Time after which a model is considered stuck
          # @param batch_size [Integer] Number of records to fetch
          # @return [Array<Hash>] Stuck read models with their aggregate classes and draft flags
          def find_stuck_read_models_with_aggregates(stuck_timeout:, batch_size:)
            stuck_models = []
            
            Yes::Core.configuration.all_read_models_with_aggregate_classes.each do |mapping|
              read_model_class = mapping[:read_model_class]
              aggregate_class = mapping[:aggregate_class]
              is_draft = mapping[:is_draft]
              
              next unless read_model_class.column_names.include?('pending_update_since')
              
              read_model_class
                .where.not(pending_update_since: nil)
                .where('pending_update_since < ?', stuck_timeout.ago)
                .limit(batch_size)
                .each do |read_model|
                  stuck_models << { read_model:, aggregate_class:, is_draft: }
                end
            end
            
            stuck_models
          end

          # Determines the aggregate ID from a read model
          # @param read_model [ActiveRecord::Base] The read model
          # @return [String] The aggregate ID
          def determine_aggregate_id(read_model)
            read_model.respond_to?(:aggregate_id) ? read_model.aggregate_id : read_model.id
          end

          # Acquires an advisory lock for the given key
          # @param lock_key [String] The lock key
          # @yield Block to execute with the lock
          def with_advisory_lock(lock_key)
            # Use PostgreSQL advisory lock
            lock_id = Zlib.crc32(lock_key)
            
            connection = ActiveRecord::Base.connection
            obtained = connection.execute("SELECT pg_try_advisory_lock(#{lock_id})").first['pg_try_advisory_lock']
            
            return yield if obtained
            
            raise "Could not obtain advisory lock for #{lock_key}"
          ensure
            connection.execute("SELECT pg_advisory_unlock(#{lock_id})") if obtained
          end

          # Logs the result of a recovery attempt
          # @param result [RecoveryResult] The recovery result
          def log_recovery_result(result)
            if result.success
              Rails.logger.info(
                "Successfully recovered read model: #{result.read_model.class.name}##{result.read_model.id}"
              )
            else
              Rails.logger.error(
                "Failed to recover read model: #{result.read_model.class.name}##{result.read_model.id} - #{result.error_message}"
              )
            end
          end

          # Access to command utilities
          def command_utilities
            Yes::Core::CommandUtilities
          end
        end
      end
    end
  end
end