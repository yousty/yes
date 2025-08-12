# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      # Provides draftable functionality for aggregates
      #
      # @example Include in an aggregate
      #   class UserAggregate < Yes::Core::Aggregate
      #     draftable
      #   end
      module Draftable
        extend ActiveSupport::Concern

        included do
          class << self
            attr_accessor :_draft_context, :_draft_aggregate, :_changes_read_model_name,
                          :_draft_foreign_key, :_is_draftable
          end
        end

        class_methods do
          # Configures the aggregate as draftable
          #
          # @param draft_aggregate [Hash, nil] The draft aggregate configuration with :context and :aggregate keys
          # @param changes_read_model [String, Symbol, nil] The changes read model name (defaults to "<read_model>_change")
          # @return [void]
          #
          # @example Use defaults
          #   draftable
          #
          # @example Override all parameters
          #   draftable draft_aggregate: { context: 'ApprenticeshipPresentation', aggregate: 'MyAggregateDraft' }, changes_read_model: 'custom_change'
          #
          # @example Override only context
          #   draftable draft_aggregate: { context: 'CustomContext' }
          #
          # @example Override only aggregate
          #   draftable draft_aggregate: { aggregate: 'CustomDraft' }
          #
          # @example Override only changes_read_model
          #   draftable changes_read_model: :article_change
          def draftable(draft_aggregate: nil, changes_read_model: nil)
            self._is_draftable = true
            
            draft_config = draft_aggregate || {}
            self._draft_context = draft_config[:context] || self.context
            self._draft_aggregate = draft_config[:aggregate] || "#{self.aggregate}Draft"
            
            self._changes_read_model_name = if changes_read_model
                                              changes_read_model.to_s
                                            else
                                              "#{read_model_name}_change"
                                            end
          end

          # Checks if the aggregate is draftable
          #
          # @return [Boolean] true if draftable, false otherwise
          def draftable?
            _is_draftable == true
          end

          # Returns the draft context
          #
          # @return [String, nil] the draft context
          def draft_context
            _draft_context
          end

          # Returns the draft aggregate name
          #
          # @return [String, nil] the draft aggregate name
          def draft_aggregate
            _draft_aggregate
          end

          # Returns the changes read model name
          #
          # @return [String, nil] the changes read model name
          def changes_read_model_name
            _changes_read_model_name
          end

          # Configures the draft foreign key
          #
          # @param key [String, Symbol] The foreign key name
          # @return [void]
          def draft_foreign_key(key)
            self._draft_foreign_key = key.to_s
          end

          # Returns the draft foreign key
          #
          # @return [String] the draft foreign key
          def change_foreign_key
            _draft_foreign_key || default_change_foreign_key
          end

          private

          # Returns the default change foreign key
          #
          # @return [String] the default change foreign key
          def default_change_foreign_key
            "#{_draft_aggregate}".underscore.sub(/_(draft|batch)/, '_change_id')
          end
        end

        # Override read_model to return changes read model when initialized as draft
        #
        # @return [ApplicationRecord] The read model or draft read model instance
        def read_model
          return super unless draft? && self.class.draftable?

          @read_model ||= changes_read_model_class.find_or_create_by(id:)
        end

        # Updates the read model and handles draft aggregate updates
        #
        # @param attributes [Hash] The attributes to update
        # @return [Boolean] true if successful
        def update_read_model(attributes)
          result = super

          update_connected_draft_aggregate if draft? && self.class.draftable?

          result
        end

        # Checks if this instance is a draft
        #
        # @return [Boolean] true if draft, false otherwise
        def draft?
          @draft == true
        end

        private

        # Returns the changes read model class
        #
        # @return [Class] the changes read model class
        def changes_read_model_class
          @changes_read_model_class ||= resolve_changes_read_model_class
        end

        # Resolves the changes read model class
        #
        # @return [Class] the resolved changes read model class
        def resolve_changes_read_model_class
          changes_read_model_name = self.class.changes_read_model_name
          return self.class.read_model_class unless changes_read_model_name

          Yes::Core::Aggregate::Dsl::ClassResolvers::ReadModel.new(
            changes_read_model_name,
            self.class.context,
            self.class.aggregate
          ).call
        end

        # Updates the connected draft aggregate's read model
        #
        # @return [void]
        def update_connected_draft_aggregate
          return if skip_draft_aggregate_update?

          draft_context = self.class.draft_context
          draft_aggregate = self.class.draft_aggregate
          change_foreign_key = self.class.change_foreign_key

          # Determine the base attribute name from the draft aggregate name
          base_attribute = draft_aggregate.underscore.sub(/_draft$/, '')

          # Check if the read model responds to this method
          return unless read_model.respond_to?(base_attribute)

          draft_aggregate_class = "#{draft_context}::#{draft_aggregate}".constantize

          changes_aggregate_read_model_class = draft_aggregate_class.read_model_class
          base_id = read_model.send(base_attribute)

          changes_aggregate_read_model_class.
            find_by(change_foreign_key => base_id)&.
            update(state: changes_aggregate_read_model_class.states[:draft])
        end

        # Checks if draft aggregate update should be skipped
        #
        # @return [Boolean] true if should skip, false otherwise
        def skip_draft_aggregate_update?
          false
        end
      end
    end
  end
end
