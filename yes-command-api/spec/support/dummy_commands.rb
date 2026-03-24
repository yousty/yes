# frozen_string_literal: true

module Dummy
  module Activity
    module Commands
      module DoSomething
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
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

      module DoSomethingMoreImpossible
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          alias aggregate_id id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(_command, _auth_data)
            raise CommandNotAuthorized, 'You cannot do this'
          end
        end

        class Validator < Yes::Core::Commands::Validator
          def self.call(_command)
            raise CommandInvalid
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
            raise CommandInvalid, 'This is not valid'
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
      end

      module DoSomethingInvalid
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
          alias aggregate_id id
        end

        class Validator < Yes::Core::Commands::Validator
          def self.call(_command)
            raise CommandInvalid.new('Command is invalid', extra: { foo: :bar })
          end
        end
      end
    end
  end

  module Actions
    module Commands
      module DoSomething
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
            true
          end
        end
      end

      module DoSomethingElse
        class Command < Yes::Core::Command
          attribute :what, Yes::Core::Types::String
          attribute :id, Yes::Core::Types::UUID
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
            raise CommandNotAuthorized, "V2 Don't do this"
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
            raise CommandInvalid, 'V2 Command is invalid'
          end
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

  module User
    module Commands
      module ChangeName
        class Command < Yes::Core::Command
          attribute :first_name, Yes::Core::Types::String
          attribute :last_name, Yes::Core::Types::String
          attribute :user_id, Yes::Core::Types::UUID
          alias aggregate_id user_id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(_command, _auth_data)
            true
          end
        end

        class Validator < Yes::Core::Commands::Validator
          def self.call(_command)
            true
          end
        end
      end
    end
  end

  module Company
    module Commands
      module ChangeName
        class Command < Yes::Core::Command
          attribute :name, Yes::Core::Types::String
          attribute :company_id, Yes::Core::Types::UUID
          alias aggregate_id company_id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(_command, _auth_data)
            true
          end
        end

        class Validator < Yes::Core::Commands::Validator
          def self.call(_command)
            true
          end
        end
      end

      module ChangeDescription
        class Command < Yes::Core::Command
          attribute :description, Yes::Core::Types::String
          attribute :company_id, Yes::Core::Types::UUID
          alias aggregate_id company_id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(_command, _auth_data)
            true
          end
        end

        class Validator < Yes::Core::Commands::Validator
          def self.call(_command)
            true
          end
        end
      end

      module DoSomethingCompounded
        class Command < Yes::Core::Commands::Group
          command 'ChangeName'
          command 'ChangeDescription'
          command 'ChangeName', subject: 'User'
        end
      end
    end
  end
end
