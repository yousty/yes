# frozen_string_literal: true

module Yes
  module Core
    module Authorization
      # Scoped memoization for the read-only lookups an authorization pass repeats.
      #
      # Authorizing a batch of commands resolves the same two things once per command:
      # the principal data (which depends only on the request's auth data) and the
      # authorized resource (which the commands of a batch commonly share). Both are
      # pure reads, and a batch is authorized in full before any of its commands is
      # executed, so no write can invalidate them while the pass is running.
      #
      # Caching is only active inside {.with_scope}. Outside one, {.fetch} just yields,
      # so callers keep their uncached behaviour unless they opt in. The store lives in
      # ActiveSupport::IsolatedExecutionState, which keeps it per thread/fiber, and
      # {.with_scope} always clears it on the way out so nothing leaks into the next
      # request.
      #
      # Cached values are shared by every {.fetch} for the same key, so callers must
      # treat them as read-only.
      #
      # @example Caching the lookups of one authorization pass
      #   LookupCache.with_scope do
      #     commands.each { |command| authorizer_for(command).call(command, auth_data) }
      #   end
      class LookupCache
        STORE_KEY = :yes_core_authorization_lookup_cache

        class << self
          # Runs the block with caching enabled, clearing the cache afterwards.
          # A nested scope reuses the cache of the outermost one and leaves clearing
          # to it.
          #
          # @yield the block to run with caching enabled
          # @return [Object] the block's return value
          def with_scope
            return yield if active?

            ActiveSupport::IsolatedExecutionState[STORE_KEY] = {}

            begin
              yield
            ensure
              ActiveSupport::IsolatedExecutionState.delete(STORE_KEY)
            end
          end

          # Returns the value cached under key, computing it via the block on a miss.
          # Without an open scope the block's value is returned uncached.
          #
          # @param key [Object] cache key
          # @yield computes the value when it is not cached yet
          # @return [Object] the cached or freshly computed value
          def fetch(key)
            return yield unless active?

            store = ActiveSupport::IsolatedExecutionState[STORE_KEY]
            return store[key] if store.key?(key)

            store[key] = yield
          end

          # @return [Boolean] whether a scope is currently open
          def active?
            ActiveSupport::IsolatedExecutionState.key?(STORE_KEY)
          end
        end
      end
    end
  end
end
