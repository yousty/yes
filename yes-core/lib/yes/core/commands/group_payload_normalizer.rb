# frozen_string_literal: true

module Yes
  module Core
    module Commands
      # Normalizes a flat or partially-nested input hash into the per-context /
      # per-subject shape expected by a command group's sub-commands.
      #
      # Supports three input forms simultaneously:
      #   * keys that match a command context are passed through verbatim,
      #   * keys that match a subject of the own context are nested one level
      #     under the own context,
      #   * any other key is nested two levels under
      #     <own_context>.<own_subject>.
      #
      # This is the shared payload-shaping primitive for
      # {Yes::Core::Commands::Group} (legacy stateless flow) and
      # {Yes::Core::Commands::CommandGroup} (aggregate-DSL flow).
      module GroupPayloadNormalizer
        # @param params [Hash] the raw input hash, including reserved keys
        # @param command_contexts [Array<Symbol>] unique contexts of all
        #   commands in the group
        # @param own_context_subjects [Array<Symbol>] subjects in the group's
        #   own context
        # @param own_context [Symbol] the group's own context
        # @param own_subject [Symbol] the group's own subject
        # @return [Hash] the normalized payload (reserved keys stripped)
        def self.call(params, command_contexts:, own_context_subjects:, own_context:, own_subject:)
          params.without(*Yes::Core::Command::RESERVED_KEYS).each_with_object({}) do |(key, value), out|
            if command_contexts.include?(key)
              out[key] = value
            elsif own_context_subjects.include?(key)
              out[own_context] ||= {}
              out[own_context][key] = value
            else
              out[own_context] ||= {}
              out[own_context][own_subject] ||= {}
              out[own_context][own_subject][key] = value
            end
          end
        end
      end
    end
  end
end
