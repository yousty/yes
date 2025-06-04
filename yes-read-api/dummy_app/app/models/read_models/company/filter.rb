# frozen_string_literal: true

module ReadModels
  module Company
    class Filter < Yousty::Eventsourcing::ReadModelFilter
      private

      def read_model_class
        ::Company
      end
    end
  end
end
