# frozen_string_literal: true

module Yes
  module Core
    module ProcessManagers
      # Base class for process managers.
      #
      # @abstract Subclass and override {#call} to implement a process manager.
      #
      # @example
      #   class MyProcessManager < Yes::Core::ProcessManagers::Base
      #     def call(event)
      #       # handle event
      #     end
      #   end
      class Base
        # Error class for process manager failures, with optional extra context.
        class Error < StandardError
          # @return [Hash] additional error context
          attr_accessor :extra

          # @param msg [String] the error message
          # @param extra [Hash] additional error information
          def initialize(msg, extra: {})
            @extra = extra
            super(msg)
          end
        end

        # Handles an event. Must be implemented by subclasses.
        #
        # @param _event [Object] the event to handle
        # @raise [NotImplementedError] if not overridden
        def call(_event)
          raise NotImplementedError
        end
      end
    end
  end
end
