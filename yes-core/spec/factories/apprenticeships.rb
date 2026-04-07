# frozen_string_literal: true

FactoryBot.define do
  factory :apprenticeship do
    name { Faker::Name.name }
    company_id { SecureRandom.uuid }
  end
end
