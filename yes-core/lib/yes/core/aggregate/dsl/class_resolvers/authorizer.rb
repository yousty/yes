# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          # Creates and registers authorizer classes for aggregates based on
          # Yousty::Eventsourcing::CommandCerbosAuthorizer.
          #
          # This class resolver generates authorizer classes associated with aggregates.
          # Each authorizer class defines a RESOURCE constant containing the
          # associated read model class and resource name used for authorization checks.
          #
          # @example Generated authorizer class structure
          #   # Generated for a 'User' aggregate
          #   class GeneratedAuthorizer < Yousty::Eventsourcing::CommandCerbosAuthorizer
          #     RESOURCE = { read_model: Auth::Resources::User, name: 'user' }.freeze
          #   end
          class Authorizer < Base
            # Initializes a new authorizer class resolver
            #
            # @param options [Yes::Core::Aggregate::HasAuthorizer::AuthorizerOptions] Data object containing:
            #   - authorizer_base_class [Class] The authorizer class to use.
            #   - context [String] The name of the context (e.g., 'CompanyManagement')
            #   - aggregate [String] The name of the aggregate (e.g., 'Company')
            #   - read_model_class [Class, nil] Optional read model class. Defaults to
            #     `Auth::Resources::<AggregateName>`.
            #   - resource_name [String, nil] Optional resource name for Cerbos. Defaults to
            #     aggregate name underscored (e.g., 'company').
            #   - authorizer_block [Proc, nil] An optional block defining the custom logic for the `call` method
            #     if `authorizer_base_class` is not `Yousty::Eventsourcing::CommandCerbosAuthorizer`.
            def initialize(options)
              @resource_name = options.resource_name
              @read_model_class = options.read_model_class
              @authorizer_class = options.authorizer_base_class
              @custom_call_logic = options.authorizer_block
              # Base class expects context_name and aggregate_name parameters
              super(options.context, options.aggregate)
            end

            # Creates and registers the authorizer class in the Yes::Core configuration
            #
            # @return [Class] The found or generated authorizer class that was registered
            def call
              Yes::Core.configuration.register_aggregate_authorizer_class(
                context_name,
                aggregate_name,
                find_or_generate_class
              )
            end

            private

            # @!attribute [r] resource_name
            #   @return [String] The name of the resource used for authorization.
            # @!attribute [r] read_model_class
            #   @return [Class] The read model class associated with the resource.
            # @!attribute [r] custom_call_logic
            #   @return [Proc, nil] The custom block provided for the call method logic.
            attr_reader :resource_name, :read_model_class, :authorizer_class, :custom_call_logic

            # @return [Symbol] Returns :authorizer as the class type
            def class_type
              :authorizer
            end

            # Generates a new authorizer class dynamically.
            # The generated class inherits from the specified authorizer_class.
            # If the base class is Yousty::Eventsourcing::CommandCerbosAuthorizer, it sets the RESOURCE constant.
            # Otherwise, if a block was provided during initialization, it defines a `call` method
            # executing that block's logic.
            #
            # @raise [ArgumentError] If the base class is not CommandCerbosAuthorizer and no block was provided.
            # @return [Class] A new authorizer class.
            def generate_class
              klass = Class.new(authorizer_class)

              if authorizer_class == Yousty::Eventsourcing::CommandCerbosAuthorizer
                klass.const_set(:RESOURCE, { read_model: read_model_class, name: resource_name }.freeze)
              else
                define_custom_call_logic(klass)
              end

              klass
            end

            # Defines custom call logic for an authorizer class when not using CommandCerbosAuthorizer
            #
            # @param klass [Class] The dynamically generated authorizer class
            # @raise [ArgumentError] If no custom_call_logic block was provided during initialization
            # @return [void]
            def define_custom_call_logic(klass)
              _custom_logic = custom_call_logic
              unless _custom_logic
                raise ArgumentError,
                      "A block must be provided to define the 'call' method logic when not using CommandCerbosAuthorizer."
              end

              # Define helper methods to access command/auth_data within the block via instance variables
              klass.define_method(:command) { @_exec_command }
              klass.define_method(:auth_data) { @_exec_auth_data }

              # Define the main call method
              klass.define_method(:call) do |current_command, current_auth_data|
                # Store command/auth_data temporarily for the block execution context
                @_exec_command = current_command
                @_exec_auth_data = current_auth_data
                begin
                  # Execute the user's block within the instance context.
                  # The block can now use the `command` and `auth_data` helper methods.
                  instance_exec(&_custom_logic)
                ensure
                  # Clean up temporary instance variables
                  remove_instance_variable(:@_exec_command) if instance_variable_defined?(:@_exec_command)
                  remove_instance_variable(:@_exec_auth_data) if instance_variable_defined?(:@_exec_auth_data)
                end
              end
            end
          end
        end
      end
    end
  end
end
