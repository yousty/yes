# frozen_string_literal: true

module Yes
  module Core
    module Utils
      # Utility module for handling caller-related operations
      module CallerUtils
        class << self
          # Extracts a formatted origin string from a caller location
          # @param caller [Thread::Backtrace::Location] caller location
          # @return [String] origin of the command, derived from caller
          def origin_from_caller(caller)
            root_path = defined?(Rails) ? Rails.root.to_s : ''
            # #absolute_path may be nil in case the code is run under irb for example. In this case - grab the script name
            # by calling #path
            caller_path = caller.absolute_path || caller.path
            caller_path.
              sub("#{root_path}/", '').
              sub('.rb', '').
              split('/').
              map { |s| s.split('_').map(&:capitalize).join }.
              join(' > ')
          end
        end
      end
    end
  end
end
