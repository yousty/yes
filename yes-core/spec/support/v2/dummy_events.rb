# frozen_string_literal: true

module Dummy
  module Company
    module Events
      class NameChanged < Yes::Core::Event
        def schema
          Dry::Schema.Params do
            required(:name).value(Yes::Core::Types::Strict::String)
          end
        end
      end

      class TitleChanged < Yes::Core::Event
        def schema
          Dry::Schema.Params do
            required(:title).value(Yes::Core::Types::Strict::String)
            required(:locale).value(Yes::Core::Types::Strict::String)
          end
        end
      end

      class DescriptionChanged < Yes::Core::Event
        payload_store_fields %i[description]

        def schema
          Dry::Schema.Params do
            required(:description).value(:string)
          end
        end
      end
    end
  end

  module User
    module Events
      class NameChanged < Yes::Core::Event
        def schema
          Dry::Schema.Params do
            required(:first_name).value(:string)
            required(:last_name).value(:string)
          end
        end

        def self.encryption_schema
          {
            key: ->(data) { data[:id] },
            attributes: %i[first_name last_name]
          }
        end
      end
    end
  end
end
