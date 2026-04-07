# frozen_string_literal: true

module Yes
  module Core
    module ReadModel
      # Provides advanced filter query building capabilities using AND/OR logic.
      # Include this module in filter classes that need to support advanced filtering.
      module FilterQueryBuilder
        AND_LOGICAL_OPERATOR = 'and'
        OR_LOGICAL_OPERATOR = 'or'
        IS_OPERATOR = 'is'
        IS_NOT_OPERATOR = 'is_not'

        FilterSchema = Dry::Schema.Params do
          required(:type).value(eql?: 'filter')
          required(:attribute).filled(:string)
          required(:operator).value(included_in?: [IS_NOT_OPERATOR, IS_OPERATOR])
          required(:value).value(:any)
        end

        FilterSetSchema = Dry::Schema.Params do
          required(:type).value(eql?: 'filter_set')
          required(:logical_operator).value(included_in?: [AND_LOGICAL_OPERATOR, OR_LOGICAL_OPERATOR])
          required(:filters).array(FilterSchema)
          optional(:scope).value(:hash)
        end

        private

        # Builds an advanced filter query based on the filter definition.
        #
        # @param base_advanced_filter_scope [ActiveRecord::Relation] The base scope to apply the filter to.
        # @param filter_definition [Hash] The filter definition to use.
        #
        # @return [ActiveRecord::Relation]
        def process_advanced_filter(base_advanced_filter_scope, filter_definition)
          return base_advanced_filter_scope if filter_definition.blank?
          raise 'Invalid filter definition' unless FilterSetSchema.call(filter_definition).success?

          @base_advanced_filter_scope = base_advanced_filter_scope
          @filter_definition = filter_definition.deep_symbolize_keys
          apply_main_scope

          return build_and_query if @filter_definition[:logical_operator] == AND_LOGICAL_OPERATOR

          build_or_query
        end

        # Chains multiple filters with AND logic.
        #
        # @return [ActiveRecord::Relation]
        def build_and_query
          scope = @base_advanced_filter_scope
          @filter_definition[:filters].each do |filter|
            scope =
              if filter[:operator] == IS_OPERATOR
                apply_is_filter(scope, filter)
              else
                apply_is_not_filter(scope, filter)
              end
          end
          scope
        end

        # Chains multiple filters with OR logic.
        #
        # @return [ActiveRecord::Relation]
        def build_or_query
          scopes = @filter_definition[:filters].map do |filter|
            if filter[:operator] == IS_OPERATOR
              apply_is_filter(@base_advanced_filter_scope, filter)
            else
              apply_is_not_filter(@base_advanced_filter_scope, filter)
            end
          end

          scope = scopes.first
          scopes[1..].each do |additional_scope|
            scope = scope.or(additional_scope)
          end

          scope
        end

        # Applies given scope to the base advanced filter scope to support authorization.
        def apply_main_scope
          return if @filter_definition[:scope].blank?

          @base_advanced_filter_scope = apply_scopes(@base_advanced_filter_scope, @filter_definition[:scope])
        end

        # Applies a single filter to the scope.
        def apply_is_filter(scope, filter)
          apply_scopes(scope, { filter[:attribute].to_sym => filter[:value] })
        end

        # Applies negation of a single filter to the scope.
        def apply_is_not_filter(scope, filter)
          scope.where.not(id: apply_is_filter(@base_advanced_filter_scope, filter))
        end
      end
    end
  end
end
