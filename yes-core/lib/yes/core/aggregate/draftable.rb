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
                          :_changes_read_model_explicit,
                          :_draft_foreign_key, :_is_draftable, :_changes_read_model_public
          end
        end

        class_methods do
          # Configures the aggregate as draftable
          #
          # @param draft_aggregate [Hash, nil] The draft aggregate configuration with :context and :aggregate keys
          # @param changes_read_model [String, Symbol, nil] The changes read model name (defaults to "<read_model>_change")
          # @param changes_read_model_public [Boolean] Whether the changes read model should be public via read API (default: true)
          # @return [void]
          #
          # @example Use defaults
          #   draftable
          #
          # @example Override all parameters
          #   draftable draft_aggregate: { context: 'ApprenticeshipPresentation', aggregate: 'MyAggregateDraft' },
          #             changes_read_model: 'custom_change', changes_read_model_public: false
          #
          # @example Override only context
          #   draftable draft_aggregate: { context: 'CustomContext' }
          #
          # @example Override only aggregate
          #   draftable draft_aggregate: { aggregate: 'CustomDraft' }
          #
          # @example Override only changes_read_model
          #   draftable changes_read_model: :article_change
          #
          # @example Make changes read model private
          #   draftable changes_read_model_public: false
          def draftable(draft_aggregate: nil, changes_read_model: nil, changes_read_model_public: true)
            self._is_draftable = true

            draft_config = draft_aggregate || {}
            self._draft_context = draft_config[:context] || context
            self._draft_aggregate = draft_config[:aggregate] || "#{aggregate}Draft"

            self._changes_read_model_explicit = changes_read_model.present?
            self._changes_read_model_name = if changes_read_model.present?
                                              changes_read_model.to_s
                                            else
                                              "#{read_model_name}_change"
                                            end

            self._changes_read_model_public = changes_read_model_public
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

          # Returns the changes read model class
          #
          # @return [Class, nil] the changes read model class
          def changes_read_model_class
            return nil unless changes_read_model_name

            Yes::Core::Aggregate::Dsl::ClassResolvers::ReadModel.new(
              changes_read_model_name,
              context,
              aggregate,
              draft: true
            ).call
          end

          # Returns whether the changes read model is public
          #
          # @return [Boolean] true if public, false otherwise
          def changes_read_model_public?
            _changes_read_model_public.nil? || _changes_read_model_public
          end

          private

          def draft_aggregate_class
            "#{draft_context}::#{draft_aggregate}::Aggregate".constantize
          end

          def draft_read_model_class
            "::#{draft_aggregate}".constantize
          end

          def main_changes_model_foreign_key
            if draft_aggregate_class.respond_to?(:changes_read_model_foreign_key)
              draft_aggregate_class.changes_read_model_foreign_key
            else
              draft_aggregate.to_s.underscore.sub(/_(draft|batch)$/, '_change_id')
            end
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

          update_draft_aggregate if self.class.draftable? && draft?

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
        def update_draft_aggregate
          main_id_method = :"#{self.class.read_model_name}_id"

          # Check if the changes read model has a foreign key that relates it to the main read model
          #
          # e.g. ApprenticeshipDraft is a draft for Apprenticeship, so main_read_model_id is :apprenticeship_id
          #
          return unless read_model.respond_to?(main_id_method)

          main_changes_model_id = read_model.send(main_id_method)

          # e.g. ::ApprenticeshipBatch.find_by(apprenticeship_edit_template_id: apprenticeship_id)&.state_draft!
          self.class.send(:draft_read_model_class).find_by(
            self.class.send(:main_changes_model_foreign_key) => main_changes_model_id
          )&.state_draft!
        end
      end
    end
  end
end
