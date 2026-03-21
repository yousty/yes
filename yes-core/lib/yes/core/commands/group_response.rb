# frozen_string_literal: true

module Yes
  module Core
    module Commands
      class GroupResponse < Response
        attribute :cmd, Yes::Core::Types.Instance(Yes::Core::Commands::Group)
        attribute? :error,
                   Yes::Core::Types.Instance(Yes::Core::Commands::Stateless::GroupHandler::CommandsError).optional
      end
    end
  end
end
