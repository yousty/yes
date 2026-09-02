# frozen_string_literal: true

module Yes
  module Core
    module Authorization
      # Default gRPC channel arguments for the Cerbos client.
      #
      # A Cerbos PDP pod that is killed or restarting fails an in-flight check with gRPC status
      # `UNAVAILABLE` ("Stream removed", "Connection refused"). gRPC retries such calls
      # transparently when the channel carries a retry policy in its service config, so the
      # caller never sees a `Cerbos::Error::Unavailable` for a blip that a second attempt on a
      # healthy pod would have answered.
      #
      # @see https://grpc.io/docs/guides/retry/
      module CerbosGrpcRetryPolicy
        SERVICE_NAME = 'cerbos.svc.v1.CerbosService'
        MAX_ATTEMPTS = 4
        INITIAL_BACKOFF = '0.1s'
        MAX_BACKOFF = '1s'
        BACKOFF_MULTIPLIER = 2
        RETRYABLE_STATUS_CODES = %w[UNAVAILABLE].freeze

        ENABLE_RETRIES_ARG = 'grpc.enable_retries'
        SERVICE_CONFIG_ARG = 'grpc.service_config'

        class << self
          # @return [Hash{String => Integer, String}] channel arguments for `Cerbos::Client.new`
          def channel_args
            {
              ENABLE_RETRIES_ARG => 1,
              SERVICE_CONFIG_ARG => service_config.to_json
            }
          end

          # @return [Hash] gRPC service config with the retry policy for the Cerbos service
          def service_config
            {
              methodConfig: [
                {
                  name: [{ service: SERVICE_NAME }],
                  retryPolicy: {
                    maxAttempts: MAX_ATTEMPTS,
                    initialBackoff: INITIAL_BACKOFF,
                    maxBackoff: MAX_BACKOFF,
                    backoffMultiplier: BACKOFF_MULTIPLIER,
                    retryableStatusCodes: RETRYABLE_STATUS_CODES
                  }
                }
              ]
            }
          end
        end
      end
    end
  end
end
