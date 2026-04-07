# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        # Handles finding and setting constants based on conventional naming
        #
        # @api private
        class ConstantResolver
          # @param class_name_convention [ClassNameConvention] Convention for generating class names
          def initialize(class_name_convention)
            @class_name_convention = class_name_convention
          end

          # Attempts to find a class based on conventional naming
          #
          # @param type [Symbol] The type of class to find (:command, :event, or :handler)
          # @param name [Symbol] The name of the class
          # @return [Class, nil] The found class or nil if not found
          def find_conventional_class(type, name)
            class_name = class_name_convention.class_name_for(type, name)
            class_name.constantize
          rescue NameError
            nil
          end

          # Sets the generated class as a constant in the appropriate module path
          #
          # @param type [Symbol] The type of class (:command, :event, or :handler, ...)
          # @param name [Symbol] The name for the class
          # @param klass [Class] The class to set as constant
          # @return [Class] The set class
          def set_constant_for(type, name, klass)
            class_name = class_name_convention.class_name_for(type, name)
            modules = class_name.split('::')
            class_name = modules.pop

            parent_module = create_module_hierarchy(modules)
            parent_module.const_set(class_name, klass)
          end

          private

          attr_reader :class_name_convention

          def create_module_hierarchy(modules)
            # Start with the root namespace if the path is absolute (starts with ::)
            base = if modules.first && modules.first.empty?
                     Object.tap { modules.shift }
                   else
                     Object
                   end

            modules.inject(base) do |mod, module_name|
              if mod.const_defined?(module_name, false)
                mod.const_get(module_name, false)
              else
                mod.const_set(module_name, Module.new)
              end
            end
          end
        end
      end
    end
  end
end
