# frozen_string_literal: true

module Dummy
  module User
    module Commands
      module ChangeFirstName
        class Command < Yes::Core::Command
          attribute :name, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          attribute? :company_id, Yes::Core::Types::UUID.optional
          alias aggregate_id id
        end
      end
    end
  end

  module Activity
    module Commands
      module DoSomething
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          attribute? :type, Yes::Core::Types::String.optional
          alias aggregate_id id
        end
      end

      module DoSomethingElse
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          alias aggregate_id id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(_command, _auth_data)
            true
          end
        end
      end

      module DoSomethingImpossible
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          alias aggregate_id id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(_command, _auth_data)
            true
          end
        end
      end

      module DoAnotherImpossible
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          alias aggregate_id id
        end
      end

      module DoSomethingLocalized
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          attribute :locale, Yes::Core::Types::String
          alias aggregate_id id
        end
      end

      module DoSomethingUnauthorized
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          alias aggregate_id id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(_command, _auth_data)
            raise CommandNotAuthorized, "Don't do this"
          end
        end

        class Validator < Yes::Core::Commands::Validator
          def self.call(_command)
            raise CommandInvalid
          end
        end
      end

      module DoSomethingAuthorized
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          alias aggregate_id id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(_command, _auth_data)
            true
          end
        end
      end

      module DoSomethingInvalid
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          alias aggregate_id id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(_command, _auth_data)
            true
          end
        end

        class Validator < Yes::Core::Commands::Validator
          def self.call(_command)
            raise CommandInvalid.new('Command is invalid', extra: { foo: :bar })
          end
        end
      end

      module DoSomethingUncommon
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          alias aggregate_id id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(_command, _auth_data)
            true
          end
        end

        class Validator < Yes::Core::Commands::Validator
          def self.call(_command)
            raise CommandInvalid
          end
        end
      end

      module DoSomethingWithNullable
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          attribute :phone, Yes::Core::Types::String.optional
          attribute :age, Yes::Core::Types::Integer.optional
          attribute? :email, Yes::Core::Types::String.optional
          alias aggregate_id id
        end
      end

      module DoSomething
        class DummyHandler
          class << self
            def stateless?
              false
            end
          end

          def call(cmd)
            Yes::Core::Commands::Response.new(cmd:)
          end

          def initialize(adapter:); end
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
