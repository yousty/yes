# frozen_string_literal: true

module Dummy
  class SomethingDone < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:what).value(Yes::Core::Types::Strict::String)
      end
    end
  end

  class Hey < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:hey).value(Yes::Core::Types::Strict::String)
      end
    end
  end

  class HeyPs < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:hey).value(Yes::Core::Types::Strict::String)
      end
    end

    def ps_fields_with_values
      { hey: 'xxx' }
    end
  end

  class Bye < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:bye).value(Yes::Core::Types::Strict::String)
      end
    end
  end

  class SomethingElseDone < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:what).value(Yes::Core::Types::Strict::String)
      end
    end
  end

  class SomethingIgnored < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:what).value(Yes::Core::Types::Strict::String)
      end
    end
  end

  class SomethingElseIgnored < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:what).value(Yes::Core::Types::Strict::String)
      end
    end
  end

  class MissingHandlerMethodDone < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:what).value(Yes::Core::Types::Strict::String)
      end
    end
  end

  class LocalizedSomethingDone < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:what).value(Yes::Core::Types::Strict::String)
        required(:locale).value(Yes::Core::Types::Strict::String)
      end
    end
  end

  class SomethingUncommon < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:what).value(Yes::Core::Types::Strict::String)
      end
    end
  end

  class UserNameChanged < Yes::Core::Event
    version(1) do
      def schema
        Dry::Schema.Params do
          required(:user_id).value(Yes::Core::Types::UUID)
          required(:first_name).value(:string)
          required(:last_name).value(:string)
        end
      end

      def up
        [
          { join: [:name, ['%{data.first_name}', '%{data.last_name}']] },
          { set: { name: '%<name>s', user_id: '%{data.user_id}', title: '' } }
        ]
      end
    end

    version(2) do
      def schema
        Dry::Schema.Params do
          required(:user_id).value(Yes::Core::Types::UUID)
          required(:name).value(:string)
          optional(:title).value(:string)
        end
      end

      def down
        [
          { split: [:split_name, '%{data.name}'] },
          {
            set: {
              first_name: '%{split_name.0}',
              last_name: '%{split_name.1}',
              user_id: '%{data.user_id}'
            }
          }
        ]
      end
    end
  end

  class UserRemoved < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:user_id).value(Yes::Core::Types::UUID)
      end
    end
  end

  class CompanyChangeContactPerson < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:user_id).value(Yes::Core::Types::UUID)
      end
    end
  end

  class ApprenticeshipYearAvailabilityChanged < Yes::Core::Event
    def schema
      Dry::Schema.Params do
        required(:availability).value(:hash)
      end
    end
  end

  class WithLargePayload < Yes::Core::Event
    payload_store_fields %i[description bio]

    def schema
      Dry::Schema.Params do
        required(:user_id).value(Yes::Core::Types::UUID)
        required(:description).value(:string)
        required(:bio).value(:string)
      end
    end
  end

  module User
    module Events
      class FirstNameChanged < Yes::Core::Event
        def schema
          Dry::Schema.Params do
            required(:name).value(:string)
          end
        end
      end
    end
  end
end

class EncryptedEvent < Yes::Core::Event
  def schema
    Dry::Schema.Params do
      required(:user_id).value(Yes::Core::Types::UUID)
      optional(:name).value(:string)
      required(:secret_name).value(:string)
    end
  end

  def self.encryption_schema
    {
      key: ->(data) { data[:user_id] },
      attributes: %i[secret_name]
    }
  end
end

class AnotherEncryptedEvent < Yes::Core::Event
  def schema
    Dry::Schema.Params do
      required(:user_id).value(:string)
      required(:secret_foo).value(:string)
    end
  end

  def self.encryption_schema
    {
      key: ->(data) { data[:user_id] },
      attributes: %i[secret_foo]
    }
  end
end
