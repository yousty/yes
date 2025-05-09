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
                          :_read_model_serializer_class
          end
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

          # Sets the read model name for this aggregate
          # @param name [String] The name for the read model
          # @param public [Boolean] Whether the read model should be public via read API
          def read_model(name, public: true)
            self._read_model_name = name.to_s.underscore
            self._read_model_public = public
          end

          # @return [Boolean] Whether the read model is public
          def read_model_public?
            _read_model_public.nil? || _read_model_public
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
        # @return [ApplicationRecord] The read model instance associated with this aggregate's ID
        # @example
        #   user_aggregate = UserAggregate.new(1)
        #   user_aggregate.read_model #=> #<User id: 1>
        def read_model
          @read_model ||= self.class.read_model_class.find_or_create_by(id:)
        end

        # Removes the read model instance for this aggregate
        def remove_read_model
          read_model.destroy
          @read_model = nil
        end

        # Rebuilds the read model by processing all events
        # @return [void]
        def rebuild_read_model
          Yes::Core::Aggregate::ReadModelRebuilder.new(self).call
        end

        delegate :revision, to: :read_model
      end
    end
  end
end
