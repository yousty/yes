# frozen_string_literal: true

module Yes
  module Core
    module Commands
      # Base class for aggregate-DSL command groups.
      #
      # A {CommandGroup} represents a compound, transactional action declared
      # inside an aggregate via the `command_group :name do … end` macro. It
      # references its sub-commands by symbol (not by class constant) so
      # declaration order in the aggregate body does not matter — resolution
      # happens lazily against the Yes configuration registry.
      #
      # The legacy {Yes::Core::Commands::Group} is intentionally untouched and
      # continues to serve the stateless command flow.
      class CommandGroup
        # Reuse the legacy Group's reserved-key Attributes struct — the shape
        # is identical for both group flavours.
        Attributes = Yes::Core::Commands::Group::Attributes

        class << self
          # @return [String] the group's owning context, e.g. "Companies"
          attr_accessor :context

          # @return [String] the group's owning aggregate, e.g. "Apprenticeship"
          attr_accessor :aggregate

          # @return [Symbol] the group's name as defined by `command_group :name`
          attr_accessor :group_name

          # @return [Array<Symbol>] ordered list of sub-command names referenced
          #   by the group; execution order matches this list
          attr_writer :sub_command_names

          def sub_command_names
            @sub_command_names ||= []
          end

          # @return [Symbol] the own context as a snake-cased symbol
          def own_context
            context.to_s.underscore.to_sym
          end

          # @return [Symbol] the own subject (aggregate name) as a snake-cased symbol
          def own_subject
            aggregate.to_s.underscore.to_sym
          end

          # Resolves the sub-command classes lazily so declaration order in the
          # aggregate body does not matter.
          #
          # @return [Array<Class>] sub-command classes in declaration order
          def sub_command_classes
            sub_command_names.map do |name|
              Yes::Core.configuration.aggregate_class(context, aggregate, name, :command) ||
                raise(ArgumentError, "Sub-command '#{name}' is not defined on #{context}::#{aggregate}")
            end
          end

          # @return [Array<Symbol>] unique contexts of all sub-commands
          def command_contexts
            sub_command_classes.map { |c| c.name.split('::').first.underscore.to_sym }.uniq
          end

          # @return [Array<Symbol>] subjects in the own context
          def own_context_subjects
            sub_command_classes.
              select { |c| c.name.split('::').first.underscore.to_sym == own_context }.
              map    { |c| c.name.split('::')[1].underscore.to_sym }.
              uniq
          end
        end

        # @return [Hash] the flat input payload (reserved keys stripped). This
        #   is what guard blocks see via `payload.<attr>` through PayloadProxy.
        attr_reader :payload

        # @return [Hash] the payload normalized into per-context/per-subject
        #   buckets. Used internally to construct sub-command instances and
        #   exposed so callers can introspect the group's per-sub-command shape.
        attr_reader :normalized_payload

        # @return [Attributes] the reserved-key attributes of the group
        attr_reader :group_attributes

        # @return [Array<Yes::Core::Command>] sub-command instances in execution order
        attr_reader :commands

        delegate :transaction, :origin, :batch_id, :metadata, :command_id, to: :group_attributes

        # @return [String, nil] the aggregate ID derived from the first sub-command
        def aggregate_id
          commands.first&.aggregate_id
        end

        # @param params [Hash] flat / partially-nested input payload, optionally
        #   carrying reserved keys (transaction, origin, batch_id, metadata,
        #   command_id, es_encrypted)
        def initialize(params)
          @group_attributes = Attributes.new(params.slice(*Yes::Core::Command::RESERVED_KEYS))
          @payload = params.except(*Yes::Core::Command::RESERVED_KEYS).symbolize_keys
          @normalized_payload = GroupPayloadNormalizer.call(
            params,
            command_contexts: self.class.command_contexts,
            own_context_subjects: self.class.own_context_subjects,
            own_context: self.class.own_context,
            own_subject: self.class.own_subject
          )
          @commands = build_commands
        end

        # @return [Hash] hash form for serialization, merging normalized payload
        #   and reserved keys (matches legacy {Yes::Core::Commands::Group#to_h})
        def to_h
          merged = normalized_payload.merge(group_attributes.to_h)
          transaction ? merged.merge(transaction:) : merged
        end

        private

        # @return [Array<Yes::Core::Command>] sub-command instances populated with
        #   the matching payload subset and the propagated reserved keys
        def build_commands
          self.class.sub_command_classes.map do |klass|
            sub_context = klass.name.split('::').first.underscore.to_sym
            sub_subject = klass.name.split('::')[1].underscore.to_sym
            subject_payload = normalized_payload.dig(sub_context, sub_subject) || {}
            attribute_payload = subject_payload.slice(*klass.attribute_names)
            klass.new(attribute_payload.merge(propagated_reserved_keys))
          end
        end

        # @return [Hash] reserved keys (excluding command_id) shared with each
        #   sub-command; command_id is intentionally omitted so each sub-command
        #   gets its own auto-generated ID via {Yes::Core::Command}'s default
        def propagated_reserved_keys
          {
            transaction: transaction,
            origin: origin,
            batch_id: batch_id,
            metadata: metadata
          }.compact
        end
      end
    end
  end
end
