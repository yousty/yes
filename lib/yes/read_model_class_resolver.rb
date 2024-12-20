# frozen_string_literal: true

module Yes
  # Resolves or generates read model classes for aggregates
  #
  # @api private
  class ReadModelClassResolver
    attr_reader :aggregate_class
    private :aggregate_class

    # @param aggregate_class [Class] The aggregate class to resolve the read model for
    def initialize(aggregate_class)
      @aggregate_class = aggregate_class
    end

    # Retrieves or generates the read model class
    #
    # @return [Class] The read model class
    # @raise [NameError] If the class cannot be found and cannot be generated
    def resolve
      @read_model_class ||= begin
        class_name = aggregate_class.read_model_name.classify
        class_name.constantize
      rescue NameError
        generate_read_model_class
      end
    end

    private

    # Dynamically generates a read model class inheriting from ApplicationRecord
    #
    # @return [Class] The generated read model class
    # @raise [NameError] If the class cannot be created
    def generate_read_model_class
      class_name = aggregate_class.read_model_name.classify
      klass = Class.new(ApplicationRecord)
      klass.table_name = aggregate_class.read_model_name.tableize
      Object.const_set(class_name, klass)
    end
  end
end 