# frozen_string_literal: true

module Dummy
  module Commands
    module Activity
      class DoSomething < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingElse < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingImpossible < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingMoreImpossible < Yes::Core::Command
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

      class DoSomethingUncommon < Yes::Core::Command
        attribute :what, Yes::Core::Types::String
        attribute :id, Yes::Core::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingElseAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        def self.call(command, auth_data)
          true
        end
      end

      class DoSomethingImpossibleAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        def self.call(command, auth_data)
          true
        end
      end

      class DoSomethingMoreImpossibleAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        def self.call(command, auth_data)
          raise CommandNotAuthorized, 'You cannot do this'
        end
      end

      class DoSomethingMoreImpossibleValidator < Yes::Core::Commands::Validator
        def self.call(command)
          raise CommandInvalid
        end
      end

      class DoSomethingUncommonAuthorizer < Yes::Core::Authorization::CommandAuthorizer
        def self.call(command, auth_data)
          true
        end
      end

      class DoSomethingUncommonValidator < Yes::Core::Commands::Validator
        def self.call(command)
          raise CommandInvalid, 'This is not valid'
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
          alias subject_id user_id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(command, auth_data)
            true
          end
        end

        class Validator < Yes::Core::Commands::Validator
          def self.call(command)
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
          alias subject_id company_id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(command, auth_data)
            true
          end
        end

        class Validator < Yes::Core::Commands::Validator
          def self.call(command)
            true
          end
        end
      end

      module ChangeDescription
        class Command < Yes::Core::Command
          attribute :description, Yes::Core::Types::String
          attribute :company_id, Yes::Core::Types::UUID
          alias subject_id company_id
        end

        class Authorizer < Yes::Core::Authorization::CommandAuthorizer
          def self.call(command, auth_data)
            true
          end
        end

        class Validator < Yes::Core::Commands::Validator
          def self.call(command)
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
