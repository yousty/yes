# frozen_string_literal: true

module Yes
  module Core
    # Base event class for all events in the system.
    # Inherits from PgEventstore::Event for PostgreSQL-based event storage.
    class Event < PgEventstore::Event
      DEFAULT_VERSION = 1
      PAYLOAD_STORE_VALUE_PREFIX = 'payload-store:'

      InvalidDataError = Class.new(StandardError)

      # Stores the event version blocks
      @versions = {}

      # Module included in versioned event subclasses to provide correct naming
      module VersionedEvent
        # Class methods for versioned events
        module ClassMethods
          # Overwrite name so that it reports the correct class name which is set from parent class
          # @return [String]
          def name
            @_class_name
          end
        end

        # Add class methods
        # @param base [Class]
        def self.included(base)
          base.extend(ClassMethods)
        end

        # Overwrite inspect so that it reports the correct class name
        # @return [String]
        def inspect
          variables = attributes_hash.keys.map { |v| "#{v}=#{public_send(v).inspect}" }
          "#<#{self.class.name} #{variables.join(' ')}>"
        end
      end

      class << self
        # Instantiates a new event. If no version is given, the default version is used.
        # @param args [Hash]
        # @return [Yes::Core::Event]
        def new(**args)
          # Prevent creating infinite subclasses of versioned events
          return super if include?(VersionedEvent)

          options = args.dup
          version = options[:version] || options.dig(:metadata, 'version')

          # Add version to custom metadata if provided
          if options[:version]
            options[:metadata] = options[:metadata]&.dup || {}
            options[:metadata]['version'] ||= version
          end

          versioned_event_class(version).new(**options)
        end

        # Returns a dynamic event class as a subclass of the current event class.
        # This is done so that we can have different versions of the same event with different
        # schemas.
        # @param version [Integer]
        # @return [Class<Yes::Core::Event>] versioned event class
        def versioned_event_class(version)
          Class.new(self, &@versions[version || DEFAULT_VERSION]).tap do |versioned_event_class|
            versioned_event_class.instance_variable_set(:@_class_name, name)
            versioned_event_class.include(VersionedEvent)
          end
        end

        # Defines the fields that are stored in the payload store
        # @param fields [Array<Symbol>]
        def payload_store_fields(fields)
          @ps_store_fields = [*fields].map(&:to_s)
        end

        # @return [Array<String>] the fields that are stored in the payload store
        def ps_store_fields
          @ps_store_fields&.map(&:to_s) || []
        end

        # Defines a new version of the event. The block is evaluated in the context of the new
        # event class.
        # @param number [Integer] The version number
        # @param blk [Proc] The block containing schema and transformations
        def version(number, &blk)
          raise ArgumentError, 'Version number must be an integer' unless number.is_a?(Integer)

          undefined_versions = (1...number).reject { |n| @versions.key?(n) }
          raise ArgumentError, "Previous versions not defined: #{undefined_versions.join(', ')}" if undefined_versions.any?

          @versions[number] = blk
        end

        # Initializes class variables for subclasses.
        # @param subclass [Class]
        def inherited(subclass)
          subclass.instance_variable_set(:@versions, {})
          subclass.instance_variable_set(:@ps_store_fields, @ps_store_fields)

          super
        end
      end

      def initialize(**attrs)
        validate(attrs[:data]) unless attrs[:skip_validation]
        super
      end

      alias to_h options_hash

      # @return [Hash]
      def as_json(*)
        to_h.transform_keys(&:to_s)
      end

      # @return [String]
      def to_json(*)
        as_json.to_json(*)
      end

      # @return [Hash] payload store fields with their values
      def ps_fields_with_values
        data.select do |_, value|
          next unless value.is_a?(String)

          value.start_with?(PAYLOAD_STORE_VALUE_PREFIX) && value.split(':').last =~ Types::UUID_REGEXP
        end
      end

      # Checks whether the event contains encrypted data
      # @return [Boolean]
      def encrypted?
        metadata&.key?('encryption') && !metadata['encryption'].empty?
      end

      # @return [Integer] the event version
      def version
        metadata['version'] || DEFAULT_VERSION
      end

      # @param version [Integer] the event version
      def version=(version)
        metadata['version'] = version
      end

      # @return [Hash] the otl context
      # @param type [Symbol, nil] :publisher or :root
      def otl_context(type:)
        return metadata['otl_contexts'] unless type

        metadata.dig('otl_contexts', type.to_s) || {}
      end

      # @param context [Hash] the otl context
      #  @option context [String] :traceparent the standard open https://www.w3.org/TR/trace-context/#header-name
      # @param type [Symbol, nil] :publisher or :root
      def otl_context=(context, type:)
        return metadata['otl_contexts'] = context unless type

        metadata['otl_contexts'] ||= {}
        metadata['otl_contexts'][type.to_s] = context
      end

      # Transforms the event to a new version
      # @param direction [Symbol] :up or :down
      # @return [Event] the transformed event
      def transform(direction)
        return self unless self.class.include?(VersionedEvent)
        raise ArgumentError, 'Direction is not valid' unless %i[up down].include?(direction)

        transformed_event = DataTransformation.new(send(direction), data).call
        v = direction == :up ? version + 1 : version - 1
        Yes::Core::Event.new(data: transformed_event, version: v)
      end

      # event schema
      def schema; end

      private

      # @param data [Hash]
      # @return [void]
      def validate(data)
        validation_schema = schema
        return unless validation_schema

        validation = validation_schema.call(data || {})
        errors = validation.errors.to_h.dup
        validate_ps_values(data, errors)
        return if errors.empty?

        raise(InvalidDataError.new(message: "#{validation_schema.class.name} #{errors}"))
      end

      # Check if a field trapped to errors list because it now has payload store value. If so - remove it from errors
      # list. Otherwise - add another error that it must be a valid payload store value.
      # @param data [Hash]
      # @param errors [Hash<Symbol => Array<String>>]
      # @return [void]
      def validate_ps_values(data, errors)
        errors.each do |field, messages|
          next unless self.class.ps_store_fields.include?(field.to_s)
          next errors.delete(field) if valid_ps_value?(data[field] || data[field.to_s])

          messages.push('or must be a correct payload store value')
        end
      end

      # @param value [Object]
      # @return [Boolean]
      def valid_ps_value?(value)
        Types::PAYLOAD_STORE_TYPE.call(value)
        true
      rescue Dry::Types::ConstraintError
        false
      end
    end
  end
end
