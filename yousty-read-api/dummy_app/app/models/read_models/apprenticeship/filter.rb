# frozen_string_literal: true

module ReadModels
  module Apprenticeship
    class Filter < Yousty::Eventsourcing::ReadModelFilter
      has_scope :ids do |_controller, scope, value|
        scope.by_id(value.split(','))
      end

      has_scope :dropout_enabled, type: :boolean

      has_scope :order_by_created_at do |_controller, scope, value|
        scope.order(created_at: value)
      end

      private

      def read_model_class
        ::Apprenticeship
      end
    end
  end
end
