# frozen_string_literal: true

FactoryBot.define do
  factory :apprenticeship do
    company
    dropout_enabled { false }
  end
end
