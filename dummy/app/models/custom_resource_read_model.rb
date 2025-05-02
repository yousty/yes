# frozen_string_literal: true

# Mock read model class for testing custom resource authorization
class CustomResourceReadModel < Yes::Core::ApplicationRecord
  self.table_name = 'test_custom_resources'

  # Method that would be used by Cerbos authorizer
  def auth_attributes
    { custom_id: id || '', custom_attribute: 'test-value' }
  end
end
