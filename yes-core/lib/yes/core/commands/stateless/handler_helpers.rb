# frozen_string_literal: true

module Yes
  module Core
    module Commands
      module Stateless
        # Provides helper methods for checking event stream state in stateless command handlers.
        # Includes methods for checking if subjects have been added, removed, published, etc.
        module HandlerHelpers
          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param options [Hash]
          # @return [Boolean]
          def removed?(subject, options = {})
            event_in_stream?(subject, 'Removed', options)
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param options [Hash]
          # @return [Boolean]
          def added?(subject, options = {})
            event_in_stream?(subject, 'Added', options)
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param payload [Hash]
          # @param event_name [String]
          # @param options [Hash]
          # @return [Boolean]
          def item_added?(subject, payload, event_name, options = {})
            added_event = last_event(subject, event_name, options.merge(payload: { equal: payload }))
            return false unless added_event

            removed_event = last_event(subject, event_name.sub('Added', 'Removed'),
                                       options.merge(payload: { equal: payload }))
            return true unless removed_event

            added_event.stream_revision > removed_event.stream_revision
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param payload [Hash]
          # @param event_name [String]
          # @param options [Hash]
          # @return [Boolean]
          def item_removed?(subject, payload, event_name, options = {})
            removed_event = last_event(subject, event_name, options.merge(payload: { equal: payload }))
            return false unless removed_event

            added_event = last_event(subject, event_name.sub('Removed', 'Added'),
                                     options.merge(payload: { equal: payload }))
            return true unless added_event

            removed_event.stream_revision > added_event.stream_revision
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param payload [Hash]
          # @param event_name [String]
          # @param options [Hash]
          # @return [Boolean]
          def item_assigned?(subject, payload, event_name, options = {})
            assigned_event = last_event(subject, event_name, options.merge(payload: { equal: payload }))
            return false unless assigned_event

            removed_event = last_event(subject, event_name.sub('Assigned', 'Unassigned'),
                                       options.merge(payload: { equal: payload }))
            return true unless removed_event

            assigned_event.stream_revision > removed_event.stream_revision
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param payload [Hash]
          # @param event_name [String]
          # @param options [Hash]
          # @return [Boolean]
          def item_unassigned?(subject, payload, event_name, options = {})
            unassigned_event = last_event(subject, event_name, options.merge(payload: { equal: payload }))
            return false unless unassigned_event

            added_event = last_event(subject, event_name.sub('Unassigned', 'Assigned'),
                                     options.merge(payload: { equal: payload }))
            return true unless added_event

            unassigned_event.stream_revision > added_event.stream_revision
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param options [Hash]
          # @return [Boolean]
          def unpublished?(subject, options = {})
            published_event = last_event(subject, 'Published', options)
            return true unless published_event

            unpublished_event = last_event(subject, 'Unpublished', options)
            return false unless unpublished_event

            unpublished_event.stream_revision > published_event.stream_revision
          end

          # @see #unpublished?
          def published?(...)
            !unpublished?(...)
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param event_name [String]
          # @param options [Hash]
          # @return [Boolean]
          def activated?(subject, event_name, options = {})
            activated_event = last_event(subject, event_name, options)
            return false unless activated_event

            deactivated_event = last_event(subject, event_name.sub('Activated', 'Deactivated'), options)
            return true unless deactivated_event

            activated_event.stream_revision > deactivated_event.stream_revision
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param event_name [String]
          # @param options [Hash]
          # @return [Boolean]
          def deactivated?(subject, event_name, options = {})
            deactivated_event = last_event(subject, event_name, options)
            return false unless deactivated_event

            activated_event = last_event(subject, event_name.sub('Deactivated', 'Activated'), options)
            return true unless activated_event

            deactivated_event.stream_revision > activated_event.stream_revision
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param event_name [String]
          # @param options [Hash]
          # @return [Boolean]
          def enabled?(subject, event_name, options = {})
            enabled_event = last_event(subject, event_name, options)
            return false unless enabled_event

            disabled_event = last_event(subject, event_name.sub('Enabled', 'Disabled'), options)
            return true unless disabled_event

            enabled_event.stream_revision > disabled_event.stream_revision
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param event_name [String]
          # @param options [Hash]
          # @return [Boolean]
          def disabled?(subject, event_name, options = {})
            disabled_event = last_event(subject, event_name, options)
            return false unless disabled_event

            enabled_event = last_event(subject, event_name.sub('Disabled', 'Enabled'), options)
            return true unless enabled_event

            disabled_event.stream_revision > enabled_event.stream_revision
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param payload [Hash]
          # @param event_name [String]
          # @param options [Hash]
          # @return [Boolean]
          def event_exists_with_payload?(subject, payload, event_name, options = {})
            event_in_stream?(subject, event_name, options.merge(payload:))
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param event_name [String]
          # @param options [Hash]
          # @return [Boolean]
          def event_in_stream?(subject, event_name, options = {})
            last_event(subject, event_name, options).present?
          end
          alias changed? event_in_stream?

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param payload [Hash]
          # @param event_name [String]
          # @return [Boolean]
          def no_change?(subject, payload, event_name)
            options = { resolve_payload: true }
            options[:locale] = payload[:locale] if payload[:locale]
            event = last_event(
              subject,
              event_name,
              options,
              skip_decryption: false
            )

            return false unless event

            payload = payload.as_json
            event.data.all? { |k, v| payload[k] == v }
          end

          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param payload_field_key [String]
          # @param event_name [String]
          # @param options [Hash]
          # @option options [Hash] :payload
          # @option options [String] :locale
          # @option options [Boolean] :resolve_payload
          # @return [Boolean]
          def partial_payload_field_changed?(subject, payload_field_key, event_name, options = {})
            stream = subject.stream
            enumerable_events = load_events(stream, options: { direction: 'Forwards' })

            partial_data = {}
            event_type = "#{subject.context}::#{subject.subject}#{event_name}"

            enumerable_events.each do |result|
              result.each do |event|
                next unless event.type == event_type
                next if options[:locale] && skip?(options[:locale], event)

                event = resolve_payloads(event) if options[:payload] || options[:resolve_payload]

                event.data[payload_field_key.to_s].each do |key, value|
                  partial_data[key] = value
                end
              end
            end

            partial_data.stringify_keys.merge(options[:payload].stringify_keys) != partial_data.stringify_keys
          rescue PgEventstore::StreamNotFoundError
            true
          end

          # @param locale [String]
          # @param event [PgEventstore::Event]
          # @return [Boolean]
          def skip?(locale, event)
            event_locale = event.data.transform_keys(&:to_s)['locale'].to_s
            return false if event_locale.empty?

            event_locale != locale.to_s
          end

          private

          # Returns the last event of the given event_name for the given subject and context
          # @param subject [Yes::Core::Commands::Stateless::Subject]
          # @param event_name [String]
          # @param options [Hash]
          # @option options [Hash] :payload the payload to match, divided into :equal and :not_equal
          #   example: { equal: { medium_id: '123' }, not_equal: { position: 3 } }
          # @param skip_decryption [Boolean]
          # @return [PgEventstore::Event, nil]
          def last_event(subject, event_name, options = {}, skip_decryption: true)
            event_type = "#{subject.context}::#{subject.subject}#{event_name}"
            stream = subject.stream

            events_cache[stream] ||= {}
            return events_cache[stream][event_type] if !options[:payload] && events_cache[stream][event_type]

            events = load_events(stream, options:, skip_decryption:)

            events.each do |result|
              result.each do |event|
                next unless event.type == event_type
                next if options[:locale] && skip?(options[:locale], event)

                event = resolve_payloads(event) if options[:payload] || options[:resolve_payload]

                events_cache[stream][event.type] ||= event

                next if options[:payload] && !payload_matches?(event.data, options[:payload])

                return event
              end
            end

            nil
          rescue PgEventstore::StreamNotFoundError
            nil
          end

          # @param stream [PgEventstore::Stream]
          # @param options [Hash]
          # @option options [String] :direction 'Backwards' or 'Forwards'
          # @option options [Symbol] :from_revision :start or :end
          # @param skip_decryption [Boolean]
          # @return [Enumerator]
          def load_events(stream, options: {}, skip_decryption: true)
            options = { direction: 'Backwards' }.merge(options)
            middlewares = Middlewares.without(:encryptor) if skip_decryption
            PgEventstore.client.read_paginated(stream, options:, middlewares:)
          end

          # @param event [PgEventstore::Event]
          # @return [PgEventstore::Event]
          def resolve_payloads(event)
            Yes::Core::PayloadStore::Lookup.new.call(event).each do |key, value|
              event.data[key.to_s] = value
            end

            event
          end

          # @param event_data [Hash]
          # @param payload [Hash]
          # @return [Boolean]
          def payload_matches?(event_data, payload)
            (payload[:equal] || {}).all? { |k, v| event_data[k.to_s] == v } &&
              (payload[:not_equal] || {}).all? { |k, v| event_data[k.to_s] != v }
          end

          # Define the implementation in your class.
          # @return [Hash]
          def events_cache
            raise NotImplementedError
          end
        end
      end
    end
  end
end
