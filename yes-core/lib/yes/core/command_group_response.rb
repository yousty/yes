# frozen_string_literal: true

module Yes
  module Core
    class CommandGroupResponse < CommandResponse
      attribute :cmd, Yousty::Eventsourcing::Types.Instance(Yousty::Eventsourcing::CommandGroup)
      attribute? :error,
                 Yousty::Eventsourcing::Types.Instance(Yousty::Eventsourcing::Stateless::CommandGroupHandler::CommandsError).optional
    end
  end
end
