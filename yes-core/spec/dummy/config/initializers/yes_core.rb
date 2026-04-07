# frozen_string_literal: true

require_relative '../../app/lib/dev_auth_adapter'

Yes::Core.configure do |config|
  config.auth_adapter = DevAuthAdapter.new
  config.aggregate_shortcuts = true
end
