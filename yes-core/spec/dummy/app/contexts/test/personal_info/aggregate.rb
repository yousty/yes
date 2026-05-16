# frozen_string_literal: true

module Test
  module PersonalInfo
    class Aggregate < Yes::Core::Aggregate
      # Use the shared read model
      read_model 'shared_profile_read_model'

      # Define attributes for personal information
      attribute :first_name, :string
      attribute :last_name, :string
      attribute :email, :email
      attribute :birth_date, :string

      # Command to update personal information
      command :update_personal_info do
        payload first_name: :string, last_name: :string, email: :email, birth_date: :string
      end

      # Individual commands for each field
      command :change_name do
        payload first_name: :string, last_name: :string
      end

      command :change_email do
        payload email: :email

        guard :valid_email do
          payload.email.include?('@')
        end
      end

      command :change_birth_date do
        payload birth_date: :string
      end

      # A simple group that fans the three change_* commands out as one
      # atomic transition with its own guard set.
      command_group :update_personal_info_group do
        command :change_name
        command :change_email
        command :change_birth_date

        guard(:email_present) { payload.email.present? }
      end
    end
  end
end
