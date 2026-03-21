# frozen_string_literal: true

require 'date'
require 'dry-types'

module Yes
  module Core
    # Type definitions for the Yes event sourcing framework.
    #
    # Provides generic types built on Dry::Types for use in commands, events,
    # and attribute definitions. Domain-specific types can be registered by
    # consuming applications via {.register}.
    #
    # @example Registering a custom type
    #   Yes::Core::Types.register(:team_role, Yes::Core::Types::String.enum('lead', 'member'))
    module Types
      include Dry.Types()

      # @!group Constants

      EMPTY_STRING = /\A\s*\z/

      UUID_REGEXP_BASE = /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}/
      UUID_REGEXP = /\A#{UUID_REGEXP_BASE}\z/i

      DATE_TIME_REGEXP = /\A\d{4}-\d{1,2}-\d{1,2} ([0-1][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?\z/i

      EMAIL_REGEXP = Regexp.union(::URI::MailTo::EMAIL_REGEXP, /^$/)

      URL_REGEXP = Regexp.new("^#{URI::DEFAULT_PARSER.make_regexp(%w[https])}").freeze

      # @!endgroup

      # @!group Generic Types

      UUID = Types::Strict::String.constrained(format: UUID_REGEXP)

      ORDERED_ARRAY_ASC = ->(value) { value == value.sort }

      UUIDS = Types::Array.of(UUID).constrained(case: ORDERED_ARRAY_ASC)

      DATE_TIME = Types::Strict::String.constrained(format: DATE_TIME_REGEXP)

      START_BEFORE_END = ->(value) { ::DateTime.parse(value[:start]) < ::DateTime.parse(value[:end]) }
      PERIOD = Types::Hash.schema(start: DATE_TIME, end: DATE_TIME).constrained(case: START_BEFORE_END)

      EMAIL = Types::Strict::String.constrained(format: EMAIL_REGEXP)
      EMAILS = Types::Array.of(EMAIL).constrained(case: ORDERED_ARRAY_ASC)

      URL = Types::Strict::String.constrained(format: URL_REGEXP)
      OPTIONAL_URL = Types::Strict::String.constrained(format: Regexp.union(EMPTY_STRING, URL_REGEXP))

      FileName = Types::String.constructor { |str| str ? str.strip.chomp : str }

      DateValue = Types::String.constrained(format: /^\d{4}-\d{2}-\d{2}$/)

      YEAR_FORMAT = ->(value) { value.to_s =~ /^\d{4}$/ }
      YEAR_RANGE = ->(value) { value.to_s.to_i >= 2000 && value.to_s.to_i <= 2050 }
      YearAvailabilityRange = Types::Any.constrained(case: YEAR_FORMAT).constrained(case: YEAR_RANGE)

      YEAR = YearAvailabilityRange
      YEARS = Types::Array.of(YearAvailabilityRange).constrained(case: ORDERED_ARRAY_ASC)

      YEAR_DATE_HASH_CONSTRAINT = lambda { |hash|
        hash.keys.all? { |key| YearAvailabilityRange.valid?(key.to_s) } &&
          hash.values.all? { |value| DateValue.valid?(value) }
      }
      PRESENT = ->(value) { value.size.positive? }
      YEAR_DATE_HASH = Types::Hash.constrained(case: YEAR_DATE_HASH_CONSTRAINT).constrained(case: PRESENT)

      LOCALE = Types::String.enum('de-CH', 'fr-CH', 'it-CH').constructor(&:to_s)

      DimensionValue = Types::Coercible::Integer.constrained(gteq: 0)
      DIMENSIONS = Types::Hash.schema(width: DimensionValue, height: DimensionValue)

      PAYLOAD_STORE_TYPE = Types::String.constrained(
        format: Regexp.new("\\Apayload-store:#{UUID_REGEXP_BASE}\\z", 'i')
      )

      # @!endgroup

      class << self
        # Registers a custom type that can be looked up by name.
        #
        # @param name [Symbol] the type name (e.g. :team_role)
        # @param type [Dry::Types::Type] the type definition
        # @return [void]
        # @example
        #   Yes::Core::Types.register(:subscription_type, Yes::Core::Types::String.enum('premium', 'basic'))
        def register(name, type)
          custom_types[name] = type
          const_set(name.to_s.upcase, type) unless const_defined?(name.to_s.upcase)
        end

        # Looks up a registered custom type by name.
        #
        # @param name [Symbol] the type name
        # @return [Dry::Types::Type, nil] the type or nil if not found
        def lookup(name)
          custom_types[name]
        end

        # @return [Hash{Symbol => Dry::Types::Type}] all registered custom types
        def custom_types
          @custom_types ||= {}
        end
      end
    end
  end
end
