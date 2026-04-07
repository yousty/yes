# frozen_string_literal: true

module Yes
  module Core
    class TypeLookup
      def self.type_for(type, context, obj_type = :command)
        new(type, context, obj_type).type_for
      end

      def initialize(type, context, obj_type)
        @type = type
        @context = context
        @obj_type = obj_type
      end

      def type_for # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
        return @type if basic_event_type?

        case @type
        when :lat, :lng
          @obj_type == :event ? :float : Yes::Core::Types::Coercible::Float
        when :string
          base = Yes::Core::Types::Coercible::String
          return base if @obj_type == :event

          base.prepend { |v| v.nil? ? raise(Dry::Types::CoercionError, 'nil is not a string') : v }
        when :integer
          Yes::Core::Types::Coercible::Integer
        when :boolean
          Yes::Core::Types::Strict::Bool
        when :float
          Yes::Core::Types::Coercible::Float
        when :uuid
          Yes::Core::Types::UUID
        when :uuids
          Yes::Core::Types::UUIDS
        when :email
          Yes::Core::Types::EMAIL
        when :url
          Yes::Core::Types::URL
        when :optional_url
          Yes::Core::Types::OPTIONAL_URL
        when :hash
          Yes::Core::Types::Hash
        when :years
          Yes::Core::Types::YEARS
        when :locale
          Yes::Core::Types::LOCALE
        when :year
          Yes::Core::Types::YEAR
        when :year_date_hash
          Yes::Core::Types::YEAR_DATE_HASH
        when :emails
          Yes::Core::Types::EMAILS
        when :datetime
          Yes::Core::Types::DATE_TIME
        when :date_value
          Yes::Core::Types::DateValue
        when :period
          Yes::Core::Types::PERIOD
        when :dimensions
          Yes::Core::Types::DIMENSIONS
        when :array
          Yes::Core::Types::Array
        else
          lookup_type(@type.to_s.upcase)
        end
      end

      private

      def basic_event_type?
        [':string', ':integer', ':boolean', ':float'].include?(@type) && @obj_type == :event
      end

      def lookup_type(value)
        return "#{@context}::Types::#{value}".constantize if Object.const_defined?("#{@context}::Types::#{value}")

        return Yes::Core::Types.const_get(value) if Yes::Core::Types.const_defined?(value)

        registered = Yes::Core::Types.lookup(value.downcase.to_sym)
        return registered if registered

        raise "Unknown type #{@type}"
      end
    end
  end
end
