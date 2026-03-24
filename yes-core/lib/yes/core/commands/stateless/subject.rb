# frozen_string_literal: true

module Yes
  module Core
    module Commands
      module Stateless
        # Subject object is responsible for holding subject data
        #
        # @attr subject [String]
        # @attr aggregate_id [String]
        # @attr context [String]
        # @attr stream_prefix [String] value is optional
        #
        # @example
        #   Yes::Core::Commands::Stateless::Subject.new(
        #     context: 'ApprenticeshipPresentation',
        #     subject: 'Apprenticeship',
        #     aggregate_id: '123'
        #   )
        class Subject < Data.define(:subject, :aggregate_id, :context, :stream_prefix)
          OPTIONAL_FIELDS = %i[stream_prefix].index_with(nil).freeze

          def initialize(**attrs)
            super(**OPTIONAL_FIELDS.merge(attrs))
          end

          # @return [PgEventstore::Stream]
          def stream
            parts = computed_stream_prefix.split('::')
            PgEventstore::Stream.new(context: parts[0], stream_name: parts[1..].join('::'), stream_id: aggregate_id)
          end

          # @return [String]
          def computed_stream_prefix
            stream_prefix || "#{context}::#{subject}"
          end
        end
      end
    end
  end
end
