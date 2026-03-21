# frozen_string_literal: true

module Dummy
  module Commands
    module User
      class ChangeFirstName < Yes::Core::Command
        attribute :name, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        attribute? :company_id, Yes::Core::Types::UUID.optional
        alias aggregate_id id
      end
    end
    module Activity
      class DoSomething < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        attribute? :type, Yes::Core::Types::String.optional
        alias aggregate_id id
        alias subject_id id
      end

      class DoSomethingElse < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
        alias subject_id id
      end

      class DoSomethingImpossible < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
      end

      class DoAnotherImpossible < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingLocalized < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        attribute :locale, Yes::Core::Types::String
        alias aggregate_id id
      end

      class DoSomethingUnauthorized < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingAuthorized < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingInvalid < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingUncommon < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingWithNullable < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        attribute :phone, Yes::Core::Types::String.optional
        attribute :age, Yes::Core::Types::Integer.optional
        attribute? :email, Yes::Core::Types::String.optional
        alias aggregate_id id
      end

      class DoSomethingElseAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        def self.call(_command, _auth_data)
          true
        end
      end

      class DoSomethingAuthorizedAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        def self.call(_command, _auth_data)
          true
        end
      end

      class DoSomethingImpossibleAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        def self.call(_command, _auth_data)
          true
        end
      end

      class DoSomethingUnauthorizedAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        def self.call(_command, _auth_data)
          raise CommandNotAuthorized, "Don't do this"
        end
      end

      class DoSomethingUnauthorizedValidator < Yes::Core::Commands::Validator
        def self.call(_command)
          raise CommandInvalid
        end
      end

      class DoSomethingInvalidAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        def self.call(_command, _auth_data)
          true
        end
      end

      class DoSomethingInvalidValidator < Yes::Core::Commands::Validator
        def self.call(command)
          raise CommandInvalid.new('Command is invalid', extra: { foo: :bar })
        end
      end

      class DoSomethingUncommonAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        def self.call(_command, _auth_data)
          true
        end
      end

      class DoSomethingUncommonValidator < Yes::Core::Commands::Validator
        def self.call(command)
          raise CommandInvalid
        end
      end

      class DummyHandler
        class << self
          def stateless?
            false
          end
        end

        def call(cmd)
          Yes::Core::Commands::Response.new(cmd:)
        end

        def initialize(adapter:)
        end
      end
    end
  end

  module V23
    module Activity
      class DoSomething < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
      end
    end
  end
end
