# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        #
        # Class which converts attributes passed to Yes::Core::Aggregate::command in shorthand
        # form to list of attributes and commands to define
        #
        class CommandShortcutExpander
          ExpandedCommandShortcut = Data.define(:attributes, :commands)
          CommandSpecification = Data.define(:name, :block)
          AttributeSpecification = Data.define(:name, :type, :options)
          class InvalidShortcut < StandardError; end

          SPECIAL_CASE_NAMES = {
            change: :change,
            enable: :enable,
            activate: :enable,
            publish: :publish
          }.freeze

          class << self
            #
            # Detects basic usage of command invocation, so the aggregate knows it's not a shortcut
            #
            # @param [Array<Object>] *args
            # @param [Hash<Object, Object>] **kwargs
            # @param [Proc] &block
            #
            # @return [Boolean]
            #
            def base_case?(*args, **kwargs, &block)
              args.size == 1 && kwargs.empty? && block.present?
            end
          end

          attr_reader :args, :kwargs, :block

          #
          # Takes all parameters passed to command invocation
          #
          # @param [Array<Object>] *args
          # @param [Hash<Object, Object>] **kwargs
          # @param [Proc] &block
          #
          def initialize(*args, **kwargs, &block)
            @args = args
            @kwargs = kwargs
            @block = block
          end

          #
          # Expands shortcut to Data object with list of attributes and commands
          #
          # @raise [InvalidShortcut] if shortcut is not recognized
          # @return [ExpandedCommandShortcut] list of attributes and commands to
          # generate
          #
          def call
            case args
            in [[Symbol, Symbol], Symbol]
              handle_toggle_commands
            in [Symbol => name, *]
              raise InvalidShortcut unless SPECIAL_CASE_NAMES.include?(name)

              send(:"handle_#{SPECIAL_CASE_NAMES[name]}_command")
            else
              raise InvalidShortcut
            end
          end

          private

          def handle_toggle_commands # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
            attribute_name = args.second
            set_flag_command, unset_flag_command = args.first
            additional_block = block # needs to be captured in a local variable to ensure proper closure in this scope

            attributes = [
              AttributeSpecification.new(
                name: attribute_name,
                type: :boolean,
                options: {}
              )
            ]

            commands = [
              CommandSpecification.new(
                name: :"#{set_flag_command}_#{attribute_name}",
                block: proc do
                  guard(:no_change) { !send(attribute_name) }
                  update_state do
                    send(attribute_name) { true }
                  end
                  instance_eval(&additional_block) if additional_block.present?
                end
              ),
              CommandSpecification.new(
                name: :"#{unset_flag_command}_#{attribute_name}",
                block: proc do
                  guard(:no_change) { send(attribute_name) }
                  update_state do
                    send(attribute_name) { false }
                  end
                  instance_eval(&additional_block) if additional_block.present?
                end
              )
            ]

            ExpandedCommandShortcut.new(attributes:, commands:)
          end

          def handle_change_command # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
            raise InvalidShortcut if args.size > 3

            attribute_name = args[1]
            attribute_type = args[2].presence || :string
            localized = kwargs[:localized] || false
            additional_block = block

            payload_options = { attribute_name => attribute_type }
            payload_options[:locale] = :locale if localized

            attributes = [
              AttributeSpecification.new(
                name: attribute_name,
                type: attribute_type,
                options: { localized: }
              )
            ]

            commands = [
              CommandSpecification.new(
                name: :"change_#{attribute_name}",
                block: proc do
                  payload(**payload_options)
                  instance_eval(&additional_block) if additional_block.present?
                end
              )
            ]

            ExpandedCommandShortcut.new(attributes:, commands:)
          end

          def handle_enable_command # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
            raise InvalidShortcut if args.size > 2

            command_verb = args.first
            command_subject = args.second
            attribute_name = kwargs[:attribute].presence || command_subject
            additional_block = block

            attributes = [
              AttributeSpecification.new(
                name: attribute_name,
                type: :boolean,
                options: {}
              )
            ]

            commands = [
              CommandSpecification.new(
                name: :"#{command_verb}_#{command_subject}",
                block: proc do
                  guard(:no_change) { !send(attribute_name) }
                  update_state do
                    send(attribute_name) { true }
                  end
                  instance_eval(&additional_block) if additional_block.present?
                end
              )
            ]

            ExpandedCommandShortcut.new(attributes:, commands:)
          end

          def handle_publish_command
            raise InvalidShortcut if args.size > 1 || kwargs.present? || block.present?

            attributes = [
              AttributeSpecification.new(
                name: :published,
                type: :boolean,
                options: {}
              )
            ]

            commands = [
              CommandSpecification.new(
                name: :publish,
                block: proc do
                  guard(:no_change) { !published }
                  update_state { published { true } }
                end
              )
            ]

            ExpandedCommandShortcut.new(attributes:, commands:)
          end
        end
      end
    end
  end
end
