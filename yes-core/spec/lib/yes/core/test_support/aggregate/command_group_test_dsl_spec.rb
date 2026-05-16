# frozen_string_literal: true

require 'yes/core/test_support/aggregate/command_test_dsl'
require 'yes/core/test_support/aggregate/shared_examples'

# Exercises the `command_group` test DSL against the Test::PersonalInfo
# aggregate, which declares :update_personal_info_group fanning out
# change_name, change_email, change_birth_date.
RSpec.describe Test::PersonalInfo::Aggregate, type: :aggregate, integration: true do
  command_group 'update_personal_info_group' do
    let(:command_data) do
      {
        first_name: 'Ada',
        last_name: 'Lovelace',
        email: 'ada@example.com',
        birth_date: '1815-12-10'
      }
    end

    let(:success_attributes) do
      {
        first_name: 'Ada',
        last_name: 'Lovelace',
        email: 'ada@example.com',
        birth_date: '1815-12-10'
      }
    end

    success_group

    invalid_group 'the email is blank (group guard fails)' do
      let(:command_data) do
        {
          first_name: 'Ada',
          last_name: 'Lovelace',
          email: '',
          birth_date: '1815-12-10'
        }
      end
    end
  end
end
