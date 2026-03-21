# frozen_string_literal: true

require 'has_scope'

module Yes
  module Core
    module ReadModel
      # Inherit from this class to define your implementation. Your class should implement #read_model_class instance
      # method should determine what ActiveRecord model class to use.
      # Example usage:
      #   ```ruby
      #   class JobAppFilter < Yes::Core::ReadModel::Filter
      #     has_scope :ids do |_controller, scope, value|
      #       scope.where(id: value.split(','))
      #     end
      #     has_scope :order_by_name do |_controller, scope, value|
      #       scope.order(name: value)
      #     end
      #     has_scope :order_by_id do |_controller, scope, value|
      #       scope.order(id: value)
      #     end
      #
      #     private
      #
      #     def read_model_class
      #       ::JobApp
      #     end
      #   end
      #   ```
      #
      # Now you can use it as follows:
      #   ```ruby
      #   JobAppFilter.new(order: { name: 'asc', id: 'desc' }, filters: { ids: '1,2,3' }).call
      #   ```
      class Filter
        include HasScope
        include FilterQueryBuilder

        ORDER_DIRECTIONS = {
          'asc' => 'asc', 'desc' => 'desc', '0' => 'asc', '1' => 'desc'
        }.tap { |h| h.default = 'asc' }.freeze

        attr_accessor :options, :type
        private :options, :type

        # Returns scope of persisted filters if given filter supports saving.
        # e. g. `AdvancedFilter.where(read_model: 'apprenticeships')`
        # @return [ActiveRecord::Relation]
        def self.persisted_filter_scope
          raise NotImplementedError
        end

        # @param options [Hash]
        # @option [Hash] :order defines an order of records of your query.
        #   Example: { order: { name: 'asc', id: 'desc' } }.
        #   Note: you should have `:order_by_name` and `:order_by_id` scopes defined using `#has_scope` class method
        # @option [Hash] :filters defines a filtering of records of your query.
        #   Example: { filters: { ids: '1,2,3', name: 'Awasome-4000' } }
        #   Note: you should have `:ids` scope defined using `#has_scope` class method
        # @option [Hash] :filter_definition defines an advanced filter supporting linking multiple filters with AND/OR
        #   logic.
        #   Example:
        # {
        #   filter_definition: {
        #     type: 'filter_set',
        #     logical_operator: 'or',
        #     filters: [
        #       { type: 'filter', attribute: 'first_name', operator: 'is', value: 'Foo' },
        #       { type: 'filter', attribute: 'last_name', operator: 'is_not', value: 'Bar' }
        #     ]
        #   }
        # }
        # @param [Symbol] :type defines the type of filter to use, default is :basic. Passing :advanced is required to
        #   use the :filter_definition option.
        def initialize(options, type: :basic)
          @options = options
          @type = type
        end

        # @return [ActiveRecord::Relation]
        def call
          scope = read_model_class.order(id: :asc)
          if type == :basic
            scope = apply_scopes(scope, options[:filters]) if options[:filters].is_a?(Hash)
          else
            scope = process_advanced_filter(scope, options[:filter_definition])
          end
          scope = apply_scopes(scope.reorder(nil), ordering_options(options[:order])) if options[:order].is_a?(Hash)
          scope
        end

        private

        # Transforms a hash into a set of scopes names and normalized directions.
        # Example:
        #   Given options:
        #   ```ruby
        #   { name: '1' }
        #   ```
        #   Will result in:
        #   ```ruby
        #   { order_by_name: 'desc' }
        #   ```
        # @param options [Hash] order options
        # @return [Hash]
        def ordering_options(options)
          options.each_with_object({}) do |(column_name, direction), result|
            result[:"order_by_#{column_name}"] = ORDER_DIRECTIONS[direction]
          end
        end

        def read_model_class
          raise NotImplementedError
        end
      end
    end
  end
end
