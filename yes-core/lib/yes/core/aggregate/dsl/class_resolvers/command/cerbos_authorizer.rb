# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Command
            # Command resolver for Cerbos-based authorizers
            class CerbosAuthorizer < Authorizer
              private

              # Generates a Cerbos authorizer class with RESOURCE constant
              # and optional DSL methods for resource_attributes and cerbos_payload
              #
              # @return [Class] The generated authorizer class
              def generate_class
                klass = Class.new(command_data.aggregate_class.authorizer_class)

                # Apply Cerbos-specific overrides if we have a block
                apply_cerbos_overrides(klass) if command_data.authorizer_block

                klass
              end

              # Applies Cerbos-specific DSL overrides to allow customization
              # of resource_attributes and cerbos_payload methods
              #
              # @param klass [Class] the class being generated
              # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
              # rubocop:disable Metrics/PerceivedComplexity, Metrics/AbcSize
              def apply_cerbos_overrides(klass)
                # Store the block for later use
                user_block = command_data.authorizer_block

                # Define instance variables and accessor methods for the DSL
                klass.class_eval do # rubocop:disable Metrics/BlockLength
                  # Resource attributes storage
                  class << self
                    attr_accessor :_resource_attributes_block, :_cerbos_payload_block
                  end

                  # Define accessor methods for the DSL
                  define_method(:command) { @_command }
                  define_method(:resource) { @_resource }
                  define_method(:auth_data) { @_auth_data }

                  # Define resource_attributes method that will be called by external code
                  define_singleton_method(:resource_attributes) do |resource = nil, command = nil, &block|
                    if block
                      # Store the block for later use
                      self._resource_attributes_block = block
                    elsif _resource_attributes_block
                      # Execute the previously stored block
                      instance = new
                      instance.instance_variable_set(:@_command, command)
                      instance.instance_variable_set(:@_resource, resource)

                      begin
                        instance.instance_eval(&_resource_attributes_block)
                      ensure
                        instance.remove_instance_variable(:@_command) if instance.instance_variable_defined?(:@_command)
                        if instance.instance_variable_defined?(:@_resource)
                          instance.remove_instance_variable(:@_resource)
                        end
                      end
                    elsif defined?(super)
                      # No block defined, call the original method if available
                      super(resource, command)
                    end
                  end

                  # Define cerbos_payload method that will be called by external code
                  define_singleton_method(:cerbos_payload) do |command = nil, resource = nil, auth = nil, &block|
                    if block
                      # Store the block for later use
                      self._cerbos_payload_block = block
                    elsif _cerbos_payload_block
                      # Execute the previously stored block
                      instance = new
                      instance.instance_variable_set(:@_command, command)
                      instance.instance_variable_set(:@_resource, resource)
                      instance.instance_variable_set(:@_auth_data, auth)

                      begin
                        instance.instance_eval(&_cerbos_payload_block)
                      ensure
                        instance.remove_instance_variable(:@_command) if instance.instance_variable_defined?(:@_command)
                        if instance.instance_variable_defined?(:@_resource)
                          instance.remove_instance_variable(:@_resource)
                        end
                        if instance.instance_variable_defined?(:@_auth_data)
                          instance.remove_instance_variable(:@_auth_data)
                        end
                      end
                    elsif defined?(super)
                      # No block defined, call the original method if available
                      super(command, resource, auth)
                    end
                  end
                end

                # We need the resource_attributes and cerbos_payload to be callable from class context
                # in the user block, but also store blocks for later execution
                klass.instance_eval do
                  # Initial setup
                  self._resource_attributes_block = nil
                  self._cerbos_payload_block = nil

                  # Execute the user block to define overrides
                  instance_eval(&user_block)
                end
              end
              # rubocop:enable Metrics/PerceivedComplexity, Metrics/AbcSize
              # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity
            end
          end
        end
      end
    end
  end
end
