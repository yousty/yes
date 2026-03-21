# frozen_string_literal: true

FactoryBot.define do
  factory :job_app do
    name { Faker::Job.title }
  end
end
