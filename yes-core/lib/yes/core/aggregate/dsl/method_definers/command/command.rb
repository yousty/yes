# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module MethodDefiners
          module Command
            # Defines a command method on the aggregate class
            class Command < Base
              # @return [void]
              def call # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
                command_name = @name

                # rubocop:disable Metrics/MethodLength, Metrics/BlockLength
                aggregate_class.define_method(command_name) do |payload = {}|
                  payload = command_utilities.prepare_command_payload(command_name, payload.clone, self.class)
                  payload = command_utilities.prepare_assign_command_payload(command_name, payload)
                  cmd = command_utilities.build_command(command_name, payload)
                  guard_evaluator_class = command_utilities.fetch_guard_evaluator_class(command_name)
                  state_updater_class = command_utilities.fetch_state_updater_class(command_name)

                  response = execute_command(cmd, guard_evaluator_class)

                  if response.success?
                    locale = payload.delete(:locale)

                    # Determine which revision column to use
                    context_revision_column = "#{self.class.context.underscore}_revision"
                    revision_column = if read_model.class.column_names.include?(context_revision_column)
                                        context_revision_column.to_sym
                                      else
                                        :revision
                                      end

                    Yes::Core::CommandHandling::ReadModelRevisionGuard.call(
                      read_model,
                      response.event.stream_revision, revision_column:
                    ) do
                      state_updater = state_updater_class.new(
                        payload: payload.except(*Yousty::Eventsourcing::Command::RESERVED_KEYS),
                        aggregate: self,
                        event: response.event
                      )
                      update_read_model(
                        state_updater.call.merge(
                          revision_column => response.event.stream_revision,
                          locale:
                        )
                      )
                    end
                  end

                  response
                end
                # rubocop:enable Metrics/MethodLength, Metrics/BlockLength
              end
            end
          end
        end
      end
    end
  end
end
