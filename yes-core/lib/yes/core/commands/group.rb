# frozen_string_literal: true

module Yes
  module Core
    module Commands
      # Represents a group of commands executed in a transaction.
      # Provides DSL for defining which commands belong to the group
      # and handles payload normalization across contexts and subjects.
      class Group
        RESERVED_KEYS = Yes::Core::Command::RESERVED_KEYS

        # Meta attributes for the Group, compatible with the Command class.
        class Attributes < Dry::Struct
          class Invalid < Error; end

          attribute? :transaction, Types.Instance(TransactionDetails).optional
          attribute? :origin, Types::String.optional
          attribute? :batch_id, Types::String.optional
          attribute? :metadata, Types::Hash.optional
          attribute :command_id, (Types::UUID.default { SecureRandom.uuid })

          # @param attributes [Hash] constructor parameters
          # @raise [Invalid] if the parameters are invalid
          def self.new(attributes)
            super
          rescue Dry::Struct::Error => e
            raise Invalid.new(extra: attributes), e
          end
        end

        class << self
          # @return [Array<Class>] List of command classes used in this group
          attr_reader :commands

          # @return [Array<Symbol>] List of unique command contexts
          def command_contexts
            commands.map { _1.to_s.split('::')[0].underscore.to_sym }.uniq
          end

          # @return [Array<Symbol>] List of subjects in the current context
          def own_context_subjects
            commands
              .select { _1.to_s.split('::')[0].underscore.to_sym == own_context }
              .map { _1.to_s.split('::')[1].underscore.to_sym }.uniq
          end

          # @return [Symbol] The context of the current command group
          def own_context
            to_s.split('::')[0].underscore.to_sym
          end

          # @return [Symbol] The subject of the current command group
          def own_subject
            to_s.split('::')[1].underscore.to_sym
          end

          # Defines a command for the command group.
          #
          # @param command_name [String] the command class name, e.g. 'NameChanged'
          # @param context [String] the context of the command, defaults to the first module
          # @param subject [String] the subject of the command, defaults to the second module
          # @return [void]
          def command(command_name, context: to_s.split('::')[0], subject: to_s.split('::')[1])
            @commands ||= []
            @commands <<
              Object.const_get(
                "#{context}::#{subject}::Commands::#{command_name}::Command"
              )
          end
        end

        # @return [Hash] The payload of the command group
        attr_reader :payload

        # @return [Attributes] The attributes of the command group
        attr_reader :group_attributes

        # @return [Array<Command>] Command instances of the group's commands
        attr_reader :commands

        delegate :transaction, :origin, :batch_id, :metadata, :command_id, to: :group_attributes

        # Initialize a new Group.
        #
        # @param params [Hash] Parameters for the command group (meta attributes and command payload)
        def initialize(params)
          @group_attributes = Attributes.new(params.slice(*Yes::Core::Command::RESERVED_KEYS))
          @payload = normalized_payloads(params)
          @commands = self.class.commands.map do |command|
            command.new(
              payload.dig(command.to_s.split('::')[0].underscore.to_sym, command.to_s.split('::')[1].underscore.to_sym)
            )
          end
        end

        # Returns the command group as a hash for serialization.
        #
        # @return [Hash] payloads and meta attributes merged
        def to_h
          transaction = group_attributes.transaction
          merged = payload.merge(group_attributes.to_h)
          transaction ? merged.merge(transaction:) : merged
        end

        private

        # Normalizes the payloads for the command group.
        #
        # @param params [Hash] the input parameters
        # @return [Hash] the normalized payloads
        def normalized_payloads(params)
          params.without(RESERVED_KEYS).each_with_object({}) do |(key, value), norm_payloads|
            if key.in?(self.class.command_contexts)
              norm_payloads[key] = value
            elsif key.in?(self.class.own_context_subjects)
              norm_payloads[self.class.own_context] ||= {}
              norm_payloads[self.class.own_context][key] = value
            else
              norm_payloads[self.class.own_context] ||= {}
              norm_payloads[self.class.own_context][self.class.own_subject] ||= {}
              norm_payloads[self.class.own_context][self.class.own_subject][key] = value
            end
          end
        end
      end
    end
  end
end
