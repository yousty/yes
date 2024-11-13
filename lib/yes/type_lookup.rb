# frozen_string_literal: true

module Yes
  class TypeLookup
    def self.type_for(type, context, obj_type = :command)
      new(type, context, obj_type).type_for
    end

    def initialize(type, context, obj_type)
      @type = type
      @context = context
      @obj_type = obj_type
    end

    def type_for
      return @type if basic_event_type?

      case @type
      when :lat, :lng
        @obj_type == :event ? :float : Yousty::Eventsourcing::Types::Coercible::Float
      when :string
        Yousty::Eventsourcing::Types::Coercible::String
      when :integer
        Yousty::Eventsourcing::Types::Coercible::Integer
      when :boolean
        Yousty::Eventsourcing::Types::Strict::Bool
      when :float
        Yousty::Eventsourcing::Types::Coercible::Float
      when :uuid
        Yousty::Eventsourcing::Types::UUID
      when :email
        Yousty::Eventsourcing::Types::EMAIL
      when :url
        Yousty::Eventsourcing::Types::URL
      when :optional_url
        Yousty::Eventsourcing::Types::OPTIONAL_URL
      when :hash
        Yousty::Eventsourcing::Types::Hash
      when :years
        Yousty::Eventsourcing::Types::YEARS
      when :locale
        Yousty::Eventsourcing::Types::LOCALE
      when :media
        Yousty::Eventsourcing::Types::MEDIA
      when :subscription_type
        Yousty::Eventsourcing::Types::SUBSCRIPTION_TYPE
      when :team_member_role
        Yousty::Eventsourcing::Types::TEAM_MEMBER_ROLE
      when :year
        Yousty::Eventsourcing::Types::YEAR
      when :year_date_hash
        Yousty::Eventsourcing::Types::YEAR_DATE_HASH
      when :apprenticeship_training_year
        Yousty::Eventsourcing::Types::APPRENTICESHIP_TRAINING_YEAR
      when :emails
        Yousty::Eventsourcing::Types::EMAILS
      when :apprenticeship_application_type
        Yousty::Eventsourcing::Types::APPRENTICESHIP_APPLICATION_TYPE
      when :trial_apprenticeship_application_type
        Yousty::Eventsourcing::Types::TRIAL_APPRENTICESHIP_APPLICATION_TYPE
      when :standard_application_document_type
        Yousty::Eventsourcing::Types::STANDARD_APPLICATION_DOCUMENT_TYPE
      when :datetime
        Yousty::Eventsourcing::Types::DATE_TIME
      when :period
        Yousty::Eventsourcing::Types::PERIOD
      when :dimensions
        Yousty::Eventsourcing::Types::DIMENSIONS
      when :standard_trial_application_document_type
        lookup_type('STANDARD_TRIAL_APPLICATION_DOCUMENT_TYPE')
      when :roles
        lookup_type('ROLES')
      when :user_authorization_roles
        lookup_type('USER_AUTHORIZATION_ROLES')
      else
        raise "Unknown type #{@type}"
      end
    end

    private

    def basic_event_type?
      [':string', ':integer', ':boolean', ':float'].include?(@type) && @obj_type == :event
    end

    def lookup_type(value)
      return "#{@context}::Types::#{value}" if Object.const_defined?("#{@context}::Types::#{value}")
      "Yousty::Eventsourcing::Types::#{value}"
    end
  end
end
