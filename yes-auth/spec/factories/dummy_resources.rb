# frozen_string_literal: true

FactoryBot.define do
  factory :company do
    id { SecureRandom.uuid }
  end

  factory :apprenticeship do
    id { SecureRandom.uuid }
  end

  factory :location do
    id { SecureRandom.uuid }
  end
end
