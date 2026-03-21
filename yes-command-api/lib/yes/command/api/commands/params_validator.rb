# frozen_string_literal: true

module Yes
  module Command
    module Api
      module Commands
        # Validates the structure of command parameter hashes before deserialization.
        # Ensures each command hash contains the required keys.
        class ParamsValidator
          CommandParamsInvalid = Class.new(Yes::Core::Error)

          REQUIRED_KEYS = %i[command data context subject].freeze

          class << self
            # Validates command params.
            #
            # @param params [Array<Hash>] Array of command params
            # @raise [CommandParamsInvalid] if params are invalid
            # @return [void]
            def call(params)
              invalid = []
              raise CommandParamsInvalid, 'Commands must be an array' unless params.is_a? Array

              params.each do |command|
                missing_keys = missing_keys?(command)
                next unless missing_keys.any?

                invalid << {
                  command:,
                  error: missing_keys_message(missing_keys)
                }
              end

              raise CommandParamsInvalid.new(required_keys_message, extra: invalid) if invalid.any?
            end

            private

            # @return [String] general error message for missing keys
            def required_keys_message
              "A command must have the following keys: #{REQUIRED_KEYS.join(', ')}"
            end

            # Returns the missing keys of the given command params, if any.
            #
            # @param command [Hash] command params
            # @return [Array<Symbol>] missing keys
            def missing_keys?(command)
              REQUIRED_KEYS.reject { |s| command.key? s }
            end

            # @param missing_keys [Array<Symbol>] missing keys
            # @return [String] error message for missing keys
            def missing_keys_message(missing_keys)
              "Missing keys: #{missing_keys.sort.join(', ')}"
            end
          end
        end
      end
    end
  end
end
