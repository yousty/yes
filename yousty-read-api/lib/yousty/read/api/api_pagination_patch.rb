# frozen_string_literal: true

require 'pagy/extras/countless'

module Yousty
  module Read
    module Api
      module ApiPaginationPatch
        include Pagy::CountlessExtra

        private

        def pagy_from(collection, options)
          if Pagy::DEFAULT[:countless_minimal] && options[:include_total] != 'true'
            return countless_pagy(collection, options)
          end

          super
        end

        def countless_pagy(collection, options)
          options[:countless_minimal] = true
          options[:items] = options[:per_page]

          pagy, = pagy_countless(collection, options)
          pagy
        end
      end
    end
  end
end

ApiPagination.singleton_class.prepend(Yousty::Read::Api::ApiPaginationPatch)
