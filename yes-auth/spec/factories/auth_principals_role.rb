# frozen_string_literal: true

FactoryBot.define do
  factory :auth_principals_role, class: 'Yes::Auth::Principals::Role' do
    id { SecureRandom.uuid }
    name { 'role:name' }

    trait :super_admin do
      name { Yes::Auth::Principals::Role::SUPER_ADMIN_ROLE_NAME }
    end

    trait :company_admin do
      name { 'company:admin' }
    end

    trait :company_editor do
      name { 'company:editor' }
    end

    trait :company_recruiter do
      name { 'company:recruiter' }
    end
  end
end
