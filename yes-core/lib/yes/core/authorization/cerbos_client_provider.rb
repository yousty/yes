# frozen_string_literal: true

module Yes
  module Core
    module Authorization
      # Provides a shared Cerbos client instance for authorizer classes.
      #
      # @example Including in a class with class-level methods
      #   class MyAuthorizer
      #     class << self
      #       include Yes::Core::Authorization::CerbosClientProvider
      #     end
      #   end
      module CerbosClientProvider
        private

        # @return [Cerbos::Client] Cerbos client configured from Yes::Core configuration
        def cerbos_client
          Cerbos::Client.new(
            Yes::Core.configuration.cerbos_url,
            tls: false
          )
        end
      end
    end
  end
end
