# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      # Provides read model functionality for aggregates
      #
      # @example Include in an aggregate
      #   class UserAggregate < Yes::Core::Aggregate
      #     include Yes::Core::Concerns::HasReadModel
      #   end
      module HasReadModel
        extend ActiveSupport::Concern

        included do
          class << self
            attr_accessor :_read_model_name, :_read_model_public, :_read_model_class, :_read_model_filter_class,
                          :_read_model_serializer_class, :_read_model_enabled
          end

          # Default to enabled
          self._read_model_enabled = true
        end

        class_methods do # rubocop:disable Metrics/BlockLength
          # Returns the read model class associated with the current aggregate.
          # The class is resolved using ReadModelClassResolver, which either uses an explicitly set
          # class name or derives it from the current namespace.
          #
          # @return [Class] The read model class
          # @raise [NameError] If the read model class cannot be found
          def read_model_class
            _read_model_class
          end

          # Sets up all read model related classes for the aggregate
          #
          # @return [void]
          # @note This method initializes three components:
          #   - The read model class itself
          #   - The read model filter class for querying
          #   - The read model serializer class for data transformation
          def setup_read_model_classes
            setup_read_model
            setup_read_model_filter
            setup_read_model_serializer
          end

          # @return [String] The name of the read model
          def read_model_name
            self._read_model_name ||= "#{context}_#{aggregate}".underscore
          end

          # Sets the read model configuration for this aggregate
          # @param name [String, false] The name for the read model, or false to disable read models
          # @param public [Boolean] Whether the read model should be public via read API
          def read_model(name, public: true)
            if name == false
              self._read_model_enabled = false
              return
            end

            self._read_model_name = name.to_s.underscore
            self._read_model_public = public
          end

          # @return [Boolean] Whether the read model is public
          def read_model_public?
            _read_model_public.nil? || _read_model_public
          end

          # @return [Boolean] Whether the read model is enabled
          def read_model_enabled?
            _read_model_enabled != false
          end

          private

          def setup_read_model
            self._read_model_class = resolve_read_model_class
          end

          def setup_read_model_filter
            self._read_model_filter_class = resolve_read_model_filter_class
          end

          def setup_read_model_serializer
            self._read_model_serializer_class = resolve_read_model_serializer_class
          end

          def resolve_read_model_class
            Yes::Core::Aggregate::Dsl::ClassResolvers::ReadModel.new(read_model_name, context, aggregate).call
          end

          def resolve_read_model_filter_class
            Yes::Core::Aggregate::Dsl::ClassResolvers::ReadModelFilter.new(read_model_name, context, aggregate).call
          end

          def resolve_read_model_serializer_class
            Yes::Core::Aggregate::Dsl::ClassResolvers::ReadModelSerializer.new(
              read_model_name, context, aggregate, attributes.keys
            ).call
          end
        end

        # Updates or creates a read model with the given attributes
        #
        # @param attributes [Hash] The attributes to update the read model with
        # @return [Boolean] Returns true if the record is saved successfully
        # @raise [ActiveRecord::RecordInvalid] If the record is invalid
        def update_read_model(attributes)
          locale = attributes.delete(:locale) || I18n.locale
          I18n.with_locale(locale) do
            read_model.update!(attributes)
          end
        end

        # Retrieves or creates a read model instance for this aggregate
        #
        # @return [ApplicationRecord, nil] The read model instance associated with this aggregate's ID, or nil if disabled
        # @example
        #   user_aggregate = UserAggregate.new(1)
        #   user_aggregate.read_model #=> #<User id: 1>
        def read_model
          return nil unless self.class.read_model_enabled?

          @read_model ||= self.class.read_model_class.find_or_create_by(id:)
        end

        # Removes the read model instance for this aggregate
        def remove_read_model
          read_model.destroy
          @read_model = nil
        end

        # Rebuilds the read model by processing all events
        # @param remove [Boolean] Whether to remove the read model before rebuilding
        # @return [void]
        def rebuild_read_model(remove: true)
          Yes::Core::Aggregate::ReadModelRebuilder.new(self).call(remove:)
        end

        def revision_column
          return :revision unless self.class.read_model_enabled?

          aggregate_revision_column = "#{self.class.context.underscore}_#{self.class.aggregate.underscore}_revision"
          return aggregate_revision_column.to_sym if read_model.class.column_names.include?(aggregate_revision_column)

          :revision
        end

        # Returns the current revision number from the read model
        # @return [Integer, nil] The revision number stored in the read model, or -1 if read models are disabled
        def revision
          return -1 unless self.class.read_model_enabled?

          read_model.send(revision_column)
        end

        # Initializes the read model's revision column with the current event stream revision
        # @return [Boolean] True if the update was successful
        # @note This method bypasses validations and callbacks by using update_column
        def init_revision_from_stream
          read_model.update_column(revision_column, event_revision)
        end
      end
    end
  end
end
