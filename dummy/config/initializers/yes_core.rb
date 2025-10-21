# frozen_string_literal: true

# Configure Yes::Core
Yes::Core.configure do |config|
  # Enable aggregate shortcuts in Rails console
  # Usage: T::User.new(id) instead of Test::User::Aggregate.new(id)
  config.aggregate_shortcuts = true
end
