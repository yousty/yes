# frozen_string_literal: true

module Yes
  module Core
    module Commands
      module Stateless
        # Response object for stateless command groups
        class GroupResponse < Response
          attribute :cmd, Types.Instance(Yes::Core::Commands::Group)
          attribute? :error, Types.Instance(Yes::Core::Commands::Stateless::GroupHandler::CommandsError).optional
        end
      end
    end
  end
end
