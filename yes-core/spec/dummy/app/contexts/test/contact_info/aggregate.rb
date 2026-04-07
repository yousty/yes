# frozen_string_literal: true

module Test
  module ContactInfo
    class Aggregate < Yes::Core::Aggregate
      # Use the shared read model
      read_model 'shared_profile_read_model'

      # Define attributes for contact information
      attribute :phone_number, :string
      attribute :address, :string
      attribute :city, :string
      attribute :country, :string
      attribute :postal_code, :string

      # Command to update all contact information
      command :update_contact_info do
        payload phone_number: :string, address: :string, city: :string, country: :string, postal_code: :string

        event :contact_info_updated
      end

      # Individual commands for each field
      command :change_phone_number do
        payload phone_number: :string

        guard :valid_phone do
          # Simple validation - at least 10 digits
          payload.phone_number.gsub(/\D/, '').length >= 10
        end
      end

      command :change_address do
        payload address: :string, city: :string, postal_code: :string, country: :string
      end

      command :change_city do
        payload city: :string
      end

      command :change_country do
        payload country: :string
      end

      command :change_postal_code do
        payload postal_code: :string
      end
    end
  end
end
