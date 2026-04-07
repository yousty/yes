# frozen_string_literal: true

module ReadModels
  module JobApp
    # Filter for JobApp read model queries
    class Filter < Yes::Core::ReadModel::Filter
      has_scope :by_name
      has_scope :ids do |_controller, scope, value|
        scope.where(id: value.split(','))
      end
      has_scope :order_by_name do |_controller, scope, value|
        scope.order(name: value)
      end
      has_scope :names do |_controller, scope, value|
        scope.by_name(value.split(','))
      end

      private

      # @return [Class] the read model class for this filter
      def read_model_class
        ::JobApp
      end
    end
  end
end
