# frozen_string_literal: true

module Yes
  module Core
    module Commands
      module Stateless
        # Response object for stateless commands
        class Response < Yes::Core::Commands::Response
          attribute? :error, Types.Instance(Stateless::Handler::TransitionError).optional
        end
      end
    end
  end
end
