# frozen_string_literal: true

module Dummy
  module ProcessManagers
    # Dummy state class for testing Yes::Core::ProcessManagers::State
    #
    # @see Yes::Core::ProcessManagers::State
    class TestState < Yes::Core::ProcessManagers::State
      RELEVANT_EVENTS = ['TestEvent::Created', 'TestEvent::Updated'].freeze

      attr_accessor :name, :status

      # @return [String] the event stream identifier
      def stream
        "test-stream-#{@id}"
      end

      # @return [Array<Symbol>] required attribute names
      def required_attributes
        %i[name status]
      end

      private

      # @param event [Object] the created event
      # @return [void]
      def apply_created(event)
        @name = event.data['name']
      end

      # @param event [Object] the updated event
      # @return [void]
      def apply_updated(event)
        @status = event.data['status']
      end
    end
  end
end
