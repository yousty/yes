# frozen_string_literal: true

module Yes
  module Core
    module Utils
      # Resolves event names from command names by converting command verbs to their past tense form
      # @example
      #   EventNameResolver.call('ChangeLocation') # => :location_changed
      #   EventNameResolver.call('AddUser') # => :user_added
      class EventNameResolver
        # @return [Hash<String, String>] Mapping of command verbs to their corresponding event (past tense) forms
        COMMAND_TO_EVENT_VERBS = {
          'Change' => 'Changed',
          'Add' => 'Added',
          'Remove' => 'Removed',
          'Enable' => 'Enabled',
          'Disable' => 'Disabled',
          'Activate' => 'Activated',
          'Deactivate' => 'Deactivated',
          'Open' => 'Opened',
          'Close' => 'Closed',
          'Start' => 'Started',
          'Stop' => 'Stopped',
          'Submit' => 'Submitted',
          'Approve' => 'Approved',
          'Reject' => 'Rejected',
          'Confirm' => 'Confirmed',
          'Cancel' => 'Cancelled',
          'Complete' => 'Completed',
          'Fail' => 'Failed',
          'Resolve' => 'Resolved',
          'Reopen' => 'Reopened',
          'Reactivate' => 'Reactivated'
        }.freeze

        # Converts a command name to its corresponding event name
        # @param command_name [String, Symbol] The name of the command to convert
        # @return [Symbol, nil] The converted event name as an underscored symbol, or nil if no conversion is possible
        # @example
        #   EventNameResolver.call('ChangeLocation') # => :location_changed
        #   EventNameResolver.call(:add_user) # => :user_added
        #   EventNameResolver.call('InvalidCommand') # => nil
        def self.call(command_name)
          normalized_command_name = command_name.to_s.camelize
          COMMAND_TO_EVENT_VERBS.each do |command_verb, event_verb|
            next unless normalized_command_name.start_with?(command_verb)

            # Extract the subject (e.g. "Location" from "ChangeLocation")
            subject = normalized_command_name.delete_prefix(command_verb)
            # Return subject + verb (e.g. "LocationChanged")
            return "#{subject}#{event_verb}".underscore.to_sym
          end

          nil
        end
      end
    end
  end
end
