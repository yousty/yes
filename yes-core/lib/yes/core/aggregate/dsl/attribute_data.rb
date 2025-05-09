# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        # Data object that holds information about an attribute definition in an aggregate
        #
        # @example
        #   AttributeData.new(:name, :string, MyAggregate, context: 'users', aggregate: 'user')
        #
        class AttributeData
          attr_reader :name, :type, :context_name,
                      :aggregate_name, :aggregate_class, :localized

          # @param name [Symbol] The name of the attribute
          # @param type [Symbol] The type of the attribute
          # @param aggregate_class [Class] The aggregate class this attribute belongs to
          # @param options [Hash] Additional options for the attribute
          # @option options [String] :context The context name for the attribute
          # @option options [String] :aggregate The aggregate name
          # @option options [Boolean] :localized Whether the attribute is localized
          def initialize(name, type, aggregate_class, options = {})
            @name = name
            @type = type
            @aggregate_class = aggregate_class
            @context_name = options.delete(:context)
            @aggregate_name = options.delete(:aggregate)
            @localized = options.delete(:localized) || false
          end
        end
      end
    end
  end
end
