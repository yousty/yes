# frozen_string_literal: true

module Dummy
  module Commands
    module Activity
      class DoSomething < Yousty::Eventsourcing::Command
        attribute :what, Yousty::Eventsourcing::Types::String
        attribute :id, Yousty::Eventsourcing::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingElse < Yousty::Eventsourcing::Command
        attribute :what, Yousty::Eventsourcing::Types::String
        attribute :id, Yousty::Eventsourcing::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingImpossible < Yousty::Eventsourcing::Command
        attribute :what, Yousty::Eventsourcing::Types::String
        attribute :id, Yousty::Eventsourcing::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingMoreImpossible < Yousty::Eventsourcing::Command
        attribute :what, Yousty::Eventsourcing::Types::String
        attribute :id, Yousty::Eventsourcing::Types::UUID
        alias aggregate_id id
      end

      class DoAnotherImpossible < Yousty::Eventsourcing::Command
        attribute :what, Yousty::Eventsourcing::Types::String
        attribute :id, Yousty::Eventsourcing::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingLocalized < Yousty::Eventsourcing::Command
        attribute :what, Yousty::Eventsourcing::Types::String
        attribute :id, Yousty::Eventsourcing::Types::UUID
        attribute :locale, Yousty::Eventsourcing::Types::String
        alias aggregate_id id
      end

      class DoSomethingUncommon < Yousty::Eventsourcing::Command
        attribute :what, Yousty::Eventsourcing::Types::String
        attribute :id, Yousty::Eventsourcing::Types::UUID
        alias aggregate_id id
      end

      class DoSomethingElseAuthorizer < Yousty::Eventsourcing::CommandAuthorizer
        def self.call(command, auth_data)
          true
        end
      end

      class DoSomethingImpossibleAuthorizer < Yousty::Eventsourcing::CommandAuthorizer
        def self.call(command, auth_data)
          true
        end
      end

      class DoSomethingMoreImpossibleAuthorizer < Yousty::Eventsourcing::CommandAuthorizer
        def self.call(command, auth_data)
          raise CommandNotAuthorized, 'You cannot do this'
        end
      end

      class DoSomethingMoreImpossibleValidator < Yousty::Eventsourcing::CommandValidator
        def self.call(command)
          raise CommandInvalid
        end
      end

      class DoSomethingUncommonAuthorizer < Yousty::Eventsourcing::CommandAuthorizer
        def self.call(command, auth_data)
          true
        end
      end

      class DoSomethingUncommonValidator < Yousty::Eventsourcing::CommandValidator
        def self.call(command)
          raise CommandInvalid, 'This is not valid'
        end
      end
    end
  end

  module V23
    module Activity
      class DoSomething < Yousty::Eventsourcing::Command
        attribute :what, Yousty::Eventsourcing::Types::String
        attribute :id, Yousty::Eventsourcing::Types::UUID
        alias aggregate_id id
      end
    end
  end

  module User
    module Commands
      module ChangeName
        class Command < Yousty::Eventsourcing::Command
          attribute :first_name, Yousty::Eventsourcing::Types::String
          attribute :last_name, Yousty::Eventsourcing::Types::String
          attribute :user_id, Yousty::Eventsourcing::Types::UUID
          alias subject_id user_id
        end

        class Authorizer < Yousty::Eventsourcing::CommandAuthorizer
          def self.call(command, auth_data)
            true
          end
        end

        class Validator < Yousty::Eventsourcing::CommandValidator
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
        class Command < Yousty::Eventsourcing::Command
          attribute :name, Yousty::Eventsourcing::Types::String
          attribute :company_id, Yousty::Eventsourcing::Types::UUID
          alias subject_id company_id
        end

        class Authorizer < Yousty::Eventsourcing::CommandAuthorizer
          def self.call(command, auth_data)
            true
          end
        end

        class Validator < Yousty::Eventsourcing::CommandValidator
          def self.call(command)
            true
          end
        end
      end

      module ChangeDescription
        class Command < Yousty::Eventsourcing::Command
          attribute :description, Yousty::Eventsourcing::Types::String
          attribute :company_id, Yousty::Eventsourcing::Types::UUID
          alias subject_id company_id
        end

        class Authorizer < Yousty::Eventsourcing::CommandAuthorizer
          def self.call(command, auth_data)
            true
          end
        end

        class Validator < Yousty::Eventsourcing::CommandValidator
          def self.call(command)
            true
          end
        end
      end

      module DoSomethingCompounded
        class Command < Yousty::Eventsourcing::CommandGroup
          command 'ChangeName'
          command 'ChangeDescription'
          command 'ChangeName', subject: 'User'
        end
      end
    end
  end
end
