# frozen_string_literal: true

# Read model for job applications
class JobApp < Yes::Core::ApplicationRecord
  scope :by_name, ->(name) { where(name:) }
end
