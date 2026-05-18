# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module MethodDefiners
          module CommandGroup
            # Base class for command_group method definers.
            class Base
              def initialize(command_group_data)
                @name = command_group_data.name
                @aggregate_class = command_group_data.aggregate_class
              end

              def call
                raise NotImplementedError, "#{self.class} must implement #call"
              end

              private

              attr_reader :name, :aggregate_class
            end
          end
        end
      end
    end
  end
end
