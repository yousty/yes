# frozen_string_literal: true

module Yes
  module Concerns
    # Provides read model functionality for aggregates
    #
    # @example Include in an aggregate
    #   class UserAggregate < Yes::Aggregate
    #     include Yes::Concerns::HasReadModel
    #   end
    module HasReadModel
      extend ActiveSupport::Concern

      included do
        class_attribute :_read_model_name, :_read_model_public, :_read_model_class_name
      end

      class_methods do
        # Sets the class name for the read model.
        #
        # @param name [String] The name of the read model class.
        # @return [void]
        def read_model_class_name(name)
          self._read_model_class_name = name
        end

        # Retrieves the read model class.
        # If no explicit class name is set, it will derive the class name from the current namespace.
        #
        # @return [Class, nil] The read model class or nil if the class cannot be found
        # @example
        #   UserAggregate.read_model_class #=> User
        def read_model_class
          (self._read_model_class_name || name.deconstantize.split('::').last).safe_constantize
        end

        # @return [String] The name of the read model
        def read_model_name
          self._read_model_name ||= aggregate.underscore
        end

        # Sets the read model name for this aggregate
        # @param name [String] The name for the read model
        # @param public [Boolean] Whether the read model should be public via read API
        def read_model(name, public: true)
          self._read_model_name = name
          self._read_model_public = public
        end

        # @return [Boolean] Whether the read model is public
        def read_model_public?
          self._read_model_public.nil? ? true : self._read_model_public
        end
      end

      # Updates or creates a read model with the given attributes
      #
      # @param attributes [Hash] The attributes to update the read model with
      # @return [Boolean] Returns true if the record is saved successfully
      # @raise [ActiveRecord::RecordInvalid] If the record is invalid
      def update_read_model(attributes)
        read_model.update!(attributes)
      end

      # Retrieves or creates a read model instance for this aggregate
      #
      # @return [ApplicationRecord] The read model instance associated with this aggregate's ID
      # @example
      #   user_aggregate = UserAggregate.new(1)
      #   user_aggregate.read_model #=> #<User id: 1>
      def read_model
        @read_model ||= read_model_class.find_or_create_by(id:)
      end

      private

      # Retrieves or generates the read model class for this aggregate
      #
      # @return [Class] The read model class
      # @raise [NameError] If the class cannot be found and cannot be generated
      def read_model_class
        @read_model_class ||= begin
          class_name = self.class.read_model_name.classify
          class_name.constantize
        rescue NameError
          generate_read_model_class
        end
      end

      # Dynamically generates a read model class inheriting from ApplicationRecord
      #
      # @return [Class] The generated read model class
      # @raise [NameError] If the class cannot be created
      def generate_read_model_class
        class_name = self.class.read_model_name.classify
        klass = Class.new(ApplicationRecord)
        klass.table_name = self.class.read_model_name.tableize
        Object.const_set(class_name, klass)
      end
    end
  end
end 