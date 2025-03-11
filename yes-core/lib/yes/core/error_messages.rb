# frozen_string_literal: true

module Yes
  module Core
    # Helper class for looking up error messages from I18n
    class ErrorMessages
      class << self
        # Looks up the error message for a guard from I18n translations
        #
        # @param context_name [String] The context name
        # @param aggregate_name [String] The aggregate name
        # @param command_name [String] The command name
        # @param guard_name [Symbol] The name of the guard
        # @return [String] The error message
        def guard_error(context_name, aggregate_name, command_name, guard_name)
          context_key, aggregate_key, command_key, guard_key = normalize_keys(
            context_name, aggregate_name, command_name, guard_name
          )

          # Try to find the error message in the following order:
          # 1. Specific translation for this aggregate attribute guard
          # 2. Default fallback message
          I18n.t(
            "aggregates.#{context_key}.#{aggregate_key}.commands.#{command_key}.guards.#{guard_key}.error",
            default: "Guard '#{guard_key}' failed"
          )
        end

        private

        def normalize_keys(*keys)
          keys.map { _1.to_s.underscore }
        end
      end
    end
  end
end
