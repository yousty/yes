# frozen_string_literal: true

module Yes
  module Core
    module ProcessManagers
      # Represents the state of a subject loaded in a process manager by replaying events.
      #
      # @abstract Subclass and override {#stream}, {#required_attributes}, and implement apply_* methods.
      #
      # @example
      #   class UserState < Yes::Core::ProcessManagers::State
      #     RELEVANT_EVENTS = %w[UserCreated UserUpdated].freeze
      #
      #     attr_reader :name, :email
      #
      #     private
      #
      #     def stream
      #       PgEventstore::Stream.new(context: 'Users', stream_name: 'User', id: id)
      #     end
      #
      #     def required_attributes
      #       %i[name email]
      #     end
      #
      #     def apply_user_created(event)
      #       @name = event.data['name']
      #       @email = event.data['email']
      #     end
      #   end
      class State
        # Loads the state for a given ID.
        #
        # @param id [String, Integer] the id of the subject to be loaded
        # @return [State] a new instance with events applied
        def self.load(id)
          new(id).tap(&:load)
        end

        # @param id [String, Integer] the id of the subject to be loaded
        def initialize(id)
          @id = id
        end

        # Loads the state from relevant events.
        #
        # @return [void]
        def load
          events = relevant_events(stream)
          return unless events

          process_events(events)
        end

        # Checks if the state is valid (all required attributes are present).
        #
        # @return [Boolean] true if all required attributes are present
        def valid?
          required_attributes.all? { |attr| send(attr).present? }
        end

        private

        # @return [String, Integer] the subject ID
        attr_reader :id

        # Defines the event stream this state is loaded from.
        #
        # @abstract Must be implemented by subclasses.
        # @raise [NotImplementedError] if not implemented in subclass
        # @return [PgEventstore::Stream] the event stream
        def stream
          raise NotImplementedError, "#{self.class} must implement #stream"
        end

        # Processes the relevant events and applies them to the state.
        #
        # @param events [Hash] a hash of event types and their corresponding events
        # @raise [NotImplementedError] if an apply_* method is not implemented for an event type
        # @return [void]
        def process_events(events)
          events.each do |event_type, event|
            event_name = event_type.split('::').last
            method_name = "apply_#{event_name.underscore}"

            raise NotImplementedError, "#{self.class} must implement ##{method_name}" unless respond_to?(method_name, true)

            send(method_name, event)
          end
        end

        # Defines the required attributes for this state.
        #
        # @abstract Must be implemented by subclasses.
        # @raise [NotImplementedError] if not implemented in subclass
        # @return [Array<Symbol>] list of required attribute names
        def required_attributes
          raise NotImplementedError, "#{self.class} must implement #required_attributes"
        end

        # Retrieves relevant events for the given stream.
        #
        # @param stream [PgEventstore::Stream] the event stream to read from
        # @return [Hash, nil] a hash of relevant events, or nil if no events are found
        def relevant_events(stream)
          options = { direction: 'Backwards', filter: { event_types: self.class::RELEVANT_EVENTS } }
          PgEventstore.client.read_paginated(stream, options:).each_with_object({}) do |events, result|
            events.each do |event|
              result[event.type] ||= event

              return result if (self.class::RELEVANT_EVENTS - result.keys).empty?
            end
          end
        end
      end
    end
  end
end
