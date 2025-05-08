# frozen_string_literal: true

module Universe
  module Star
    class Aggregate < Yes::Core::Aggregate
      authorize cerbos: true

      attribute :label, :string
      attribute :size, :integer

      command :create_star do
        payload label: :string, size: :integer

        event :star_created

        authorize do
          resource_attributes { { owner_id: 'test-user-id' } }
          cerbos_payload { { principal: auth_data, resource_id: 'test-id' } }
        end
      end
    end
  end
end
