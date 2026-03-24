# frozen_string_literal: true

module Dummy
  module Commands
    module Activity
      class DummyHandler
        class << self
          def stateless?
            false
          end
        end

        def call(cmd)
          return if cmd.is_a?(Yes::Core::Commands::Group)

          Yes::Core::Commands::Response.new(cmd: cmd)
        end

        def initialize(adapter:); end
      end
    end
  end

  module User
    module Commands
      module ChangeName
        class Handler < Yes::Core::Commands::Stateless::Handler
          self.event_name = 'NameChanged'
        end
      end
    end
  end

  module Company
    module Commands
      module ChangeName
        class Handler < Yes::Core::Commands::Stateless::Handler
          self.event_name = 'NameChanged'

          def call
            return if attributes['name'] != 'Invalid name'

            invalid_transition('Invalid name', extra: { foo: 'bar' })

            super
          end
        end
      end

      module ChangeDescription
        class Handler < Yes::Core::Commands::Stateless::Handler
          self.event_name = 'DescriptionChanged'
        end
      end

      module DoSomethingCompounded
        class CommandHandler < Yes::Core::Commands::Stateless::GroupHandler
          handler 'ChangeName'
          handler 'ChangeName', subject: 'User'
          handler :custom_check

          private

          def custom_check
            return if cmd.payload[:dummy][:user][:last_name] != 'Invalid last name'

            invalid_transition('Invalid last name', extra: { boo: 'far' })

            super
          end
        end
      end
    end
  end
end
