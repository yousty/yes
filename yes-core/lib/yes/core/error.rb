# frozen_string_literal: true

module Yes
  module Core
    class Error < StandardError
      attr_reader :extra

      def initialize(message = nil, extra: nil)
        super(message)
        @extra = extra
      end
    end
  end
end
