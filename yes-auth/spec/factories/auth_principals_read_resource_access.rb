# frozen_string_literal: true

FactoryBot.define do
  factory :auth_principals_read_resource_access, class: 'Yes::Auth::Principals::ReadResourceAccess' do
    id { SecureRandom.uuid }
    principal_id { SecureRandom.uuid }
    role_id { SecureRandom.uuid }
    service { '' }
    scope { 'root' }
    resource_id { SecureRandom.uuid }
    resource_type { '' }
    auth_attributes { {} }
  end
end
