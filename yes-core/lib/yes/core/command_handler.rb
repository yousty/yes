# frozen_string_literal: true

module Yes
  module Core
    # Base command handler class for all command handlers in the system
    class CommandHandler < Yousty::Eventsourcing::Stateless::CommandHandler; end
  end
end
