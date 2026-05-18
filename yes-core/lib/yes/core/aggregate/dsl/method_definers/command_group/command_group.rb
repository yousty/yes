# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module MethodDefiners
          module CommandGroup
            # Defines `aggregate.<group_name>(payload = nil, **options)` on the
            # aggregate class. Mirrors {MethodDefiners::Command::Command} but
            # delegates to {Yes::Core::CommandHandling::CommandGroupHandler}.
            class CommandGroup < Base
              def call
                group_name = @name

                aggregate_class.define_method(group_name) do |payload = nil, **options|
                  payload = payload.clone if payload.is_a?(Hash)

                  guards = options.delete(:guards)
                  guards = true if guards.nil?
                  metadata = options.delete(:metadata)

                  if payload.nil? && !options.empty?
                    payload = options
                  elsif payload.nil?
                    payload = {}
                  end

                  Yes::Core::CommandHandling::CommandGroupHandler.new(self).call(
                    group_name, payload, guards:, metadata:
                  )
                end
              end
            end
          end
        end
      end
    end
  end
end
