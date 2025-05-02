# frozen_string_literal: true

module Test
  module CustomResource
    class Aggregate < Yes::Core::Aggregate
      # Use Cerbos with custom parameters
      authorize cerbos: true,
                read_model_class: CustomResourceReadModel,
                resource_name: 'special_resource'
    end
  end
end
