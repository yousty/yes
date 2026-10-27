# frozen_string_literal: true

# Read model that is fed by a subscription only: no aggregate owns it, although its table is the one of TestUser
class SubscriptionTestUser < Yes::Core::ApplicationRecord
  self.table_name = 'test_users'
end
