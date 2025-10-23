# frozen_string_literal: true

module Yes
  module Core
    # Base command class for all commands in the system
    class Command < Yousty::Eventsourcing::Command
      RESERVED_KEYS = (Yousty::Eventsourcing::Command::RESERVED_KEYS + %i[es_encrypted]).freeze
    end
  end
end
