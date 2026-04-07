# frozen_string_literal: true

FactoryBot.define do
  factory :auth_principals_user, class: 'Yes::Auth::Principals::User' do
    id { SecureRandom.uuid }
    auth_attributes { {} }
    identity_id { SecureRandom.uuid }

    trait :with_roles do
      transient do
        roles { [] }

        after(:create) do |user, evaluator|
          evaluator.roles.each do |role|
            user.roles << role
          end
          user.save!
        end
      end
    end
  end
end
