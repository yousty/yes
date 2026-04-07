# frozen_string_literal: true

module ReadModels
  module Company
    class Filter < Yes::Core::ReadModel::Filter
      private

      def read_model_class
        ::Company
      end
    end
  end
end
