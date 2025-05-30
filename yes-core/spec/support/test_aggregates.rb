# Dummy models for testing SharedReadModelRebuilder
require_relative 'shared_profile_read_model'

module Test
  module PersonalInfo
    # PersonalInfo Aggregate that shares a read model with ContactInfo
    class Aggregate < Yes::Core::Aggregate::Base
      # Set the read model class directly
      @read_model_class = SharedProfileReadModel

      # Define the context
      def self.context
        'Test'
      end

      # Command to change name
      command :change_name do
        # Define guard for change_name
        guard do
          true
        end

        # Define state updates
        update do |payload|
          {
            first_name: payload[:first_name],
            last_name: payload[:last_name]
          }
        end
      end

      # Command to change email
      command :change_email do
        # Define guard for change_email
        guard do
          true
        end

        # Define state updates
        update do |payload|
          {
            email: payload[:email]
          }
        end
      end

      # Command to change birth date
      command :change_birth_date do
        # Define guard for change_birth_date
        guard do
          true
        end

        # Define state updates
        update do |payload|
          {
            birth_date: payload[:birth_date]
          }
        end
      end
    end
  end

  module ContactInfo
    # ContactInfo Aggregate that shares a read model with PersonalInfo
    class Aggregate < Yes::Core::Aggregate::Base
      # Set the read model class directly
      @read_model_class = SharedProfileReadModel

      # Define the context
      def self.context
        'Test'
      end

      # Command to change phone number
      command :change_phone do
        # Define guard for change_phone
        guard do
          true
        end

        # Define state updates
        update do |payload|
          {
            phone_number: payload[:phone_number]
          }
        end
      end

      # Command to change address details
      command :change_address do
        # Define guard for change_address
        guard do
          true
        end

        # Define state updates
        update do |payload|
          {
            address: payload[:address],
            city: payload[:city],
            postal_code: payload[:postal_code],
            country: payload[:country]
          }
        end
      end

      # Command to change just the city
      command :change_city do
        # Define guard for change_city
        guard do
          true
        end

        # Define state updates
        update do |payload|
          {
            city: payload[:city]
          }
        end
      end
    end
  end
end
