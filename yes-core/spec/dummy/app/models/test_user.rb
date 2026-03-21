# frozen_string_literal: true

# Read model for Test::User::Aggregate
class TestUser < Yes::Core::ApplicationRecord
  self.table_name = 'test_users'

  # Association with location if needed
  belongs_to :location, class_name: 'TestLocation', optional: true
  
  # Scope required by Yes::Core
  scope :by_ids, ->(ids) { where(id: ids) }
end