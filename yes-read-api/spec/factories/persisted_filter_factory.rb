# frozen_string_literal: true

FactoryBot.define do
  factory :persisted_filter do
    body { {} }
    read_model { 'apprenticeships' }
  end
end
