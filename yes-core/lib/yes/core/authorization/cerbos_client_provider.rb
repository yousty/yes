# frozen_string_literal: true

module Yes
  module Core
    module Authorization
      # Provides a shared Cerbos client instance for authorizer classes.
      #
      # One client (and therefore one gRPC channel) is kept per process. `Cerbos::Client` is
      # thread-safe, but a gRPC channel must not be shared across a fork, so the client is
      # rebuilt in each forked worker.
      #
      # @example Including in a class with class-level methods
      #   class MyAuthorizer
      #     class << self
      #       include Yes::Core::Authorization::CerbosClientProvider
      #     end
      #   end
      module CerbosClientProvider
        class << self
          # @return [Cerbos::Client] the process-wide Cerbos client
          def client
            mutex.synchronize do
              reset! unless @client_pid == Process.pid
              @client ||= build_client
            end
          end

          # Drops the memoized client so the next call builds a new one (used after a fork and
          # in tests).
          # @return [void]
          def reset!
            @client = nil
            @client_pid = Process.pid
          end

          private

          # @return [Mutex]
          def mutex
            @mutex ||= Mutex.new
          end

          # @return [Cerbos::Client] client configured from Yes::Core configuration
          def build_client
            config = Yes::Core.configuration

            Cerbos::Client.new(
              config.cerbos_url,
              tls: config.cerbos_tls,
              grpc_channel_args: config.cerbos_grpc_channel_args
            )
          end
        end

        private

        # @return [Cerbos::Client] the process-wide Cerbos client
        def cerbos_client
          CerbosClientProvider.client
        end
      end
    end
  end
end
