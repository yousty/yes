# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      # Provides authorizer functionality for aggregates.
      #
      # This concern automatically sets up an authorizer class for the aggregate
      # using `Yes::Core::Aggregate::Dsl::ClassResolvers::Authorizer`.
      # The authorizer class is typically used for command authorization via Cerbos.
      #
      module HasAuthorizer
        extend ActiveSupport::Concern

        # Mutable struct for holding authorizer options
        AuthorizerOptions = Struct.new(
          :authorizer_base_class,
          :context,
          :aggregate,
          :read_model_class,
          :resource_name,
          :authorizer_block,
          keyword_init: true
        )

        included do
          class << self
            # @!attribute [rw] _authorizer_class
            #   @return [Class] The internally stored authorizer class.
            attr_accessor :_authorizer_class
          end
        end

        class_methods do # rubocop:disable Metrics/BlockLength
          # Returns the authorizer class associated with the current aggregate.
          # This class is resolved and registered during the setup process.
          #
          # @return [Class] The authorizer class (inheriting from CommandCerbosAuthorizer)
          # @raise [NameError] If the authorizer class cannot be found or generated.
          def authorizer_class
            _authorizer_class
          end

          # Finds or generates the authorizer class using `ClassResolvers::Authorizer`,
          # passing the authorizer parameters.
          # Registers the authorizer in the configuration and stores the resolved class internally.
          # @return [Class] The resolved authorizer class.
          def setup_authorizer_classes
            return unless @authorizer_options

            @authorizer_options.read_model_class ||= read_model_class

            self._authorizer_class = Yes::Core::Aggregate::Dsl::ClassResolvers::Authorizer.new(@authorizer_options).call

            commands.each_value do |command_data|
              Dsl::ClassResolvers::Command::AuthorizerFactory.create(command_data)&.call
            end
          end

          # @param cerbos [Boolean] Whether to use Cerbos authorizer.
          # @return [Class] The authorizer class.
          def authorize(cerbos: false, read_model_class: nil, resource_name: nil, &block)
            authorizer_base_class = if cerbos
                                      Yousty::Eventsourcing::CommandCerbosAuthorizer
                                    else
                                      Yousty::Eventsourcing::CommandAuthorizer
                                    end

            @authorizer_options = AuthorizerOptions.new(
              authorizer_base_class: authorizer_base_class,
              context: context,
              aggregate: aggregate,
              read_model_class: read_model_class,
              resource_name: resource_name,
              authorizer_block: block
            )
          end
        end
      end
    end
  end
end
