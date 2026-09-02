# frozen_string_literal: true

module Yes
  module Core
    # Base class for the gem's errors, carrying optional caller-supplied context.
    #
    # @example Raising with context
    #   raise Yes::Core::Error.new('could not resolve the aggregate', extra: { id: })
    #
    # @example Consuming the context safely
    #   # #extra is not guaranteed to be a Hash - type-check before merging it.
    #   payload.merge!(error.extra) if error.extra.is_a?(Hash)
    class Error < StandardError
      # Caller-supplied context, returned exactly as it was given.
      #
      # It defaults to +nil+ and is never coerced or validated, so it may be any object the
      # caller passed. Code that treats it as a Hash must therefore type-check first: a bare
      # +payload.merge!(error.extra)+ raises +TypeError+ both for the +nil+ default and for any
      # other non-Hash value. That matters most inside error-reporting hooks, where such a
      # +TypeError+ tends to be swallowed by the reporter and takes the report down with it.
      #
      # @return [Object, nil] whatever the caller supplied; +nil+ when nothing was
      attr_reader :extra

      # @param message [String, nil] the error message
      # @param extra [Object, nil] arbitrary context to attach; stored as given
      def initialize(message = nil, extra: nil)
        super(message)
        @extra = extra
      end
    end
  end
end
