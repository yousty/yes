# frozen_string_literal: true

module TestCommands
  module UserManagement
    class CreateUser < Yes::Core::Command
      attribute :name, Yousty::Eventsourcing::Types::String
      attribute :email, Yousty::Eventsourcing::Types::String
    end
  end
end