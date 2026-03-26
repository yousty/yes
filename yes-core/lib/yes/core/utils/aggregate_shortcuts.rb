# frozen_string_literal: true

module Yes
  module Core
    module Utils
      # Provides convenient shortcuts for accessing aggregate classes in Rails console
      # @example
      #   # Instead of: ApprenticeshipPresentation::Apprenticeship::Aggregate.new(id)
      #   # Use: AP::Appr.new(id)
      class AggregateShortcuts
        class << self
          # Load aggregate shortcuts in Rails console
          # Creates module aliases and constants for convenient access
          def load!
            return unless Yes::Core.configuration.aggregate_shortcuts

            load_overrides
            discover_aggregates
            create_shortcuts
            define_helper_method
          end

          # List all available shortcuts
          # @param filter [String, nil] Optional filter to show only specific context
          # @return [Hash] Hash of shortcuts and their full paths
          # @example
          #   AggregateShortcuts.list
          #   AggregateShortcuts.list('AP')
          def list(filter = nil)
            results = @shortcuts || {}
            results = results.select { |shortcut, _| shortcut.start_with?("#{filter}::") } if filter
            results
          end

          # Display shortcuts in a formatted table
          # @param filter [String, nil] Optional filter
          def display(filter = nil)
            shortcuts = list(filter)

            if shortcuts.empty?
              Rails.logger.debug { "No shortcuts found#{" for '#{filter}'" if filter}." }
              return
            end

            max_shortcut_length = shortcuts.keys.map(&:length).max

            Rails.logger.debug "\nAvailable Aggregate Shortcuts:"
            Rails.logger.debug '=' * (max_shortcut_length + 70)
            shortcuts.sort.each do |shortcut, full_path|
              Rails.logger.debug "#{shortcut.ljust(max_shortcut_length)} → #{full_path}"
            end
            Rails.logger.debug '=' * (max_shortcut_length + 70)
            Rails.logger.debug { "\nUsage: #{shortcuts.keys.first}.new(id)" } if shortcuts.any?
          end

          private

          def load_overrides
            @context_overrides = {}
            @subject_overrides = {}

            config_path = Rails.root.join('config/aggregate_shortcuts.yml')
            return unless File.exist?(config_path)

            config = YAML.load_file(config_path)
            @context_overrides = config['contexts'] || {}
            @subject_overrides = config['subjects'] || {}
          rescue StandardError => e
            Rails.logger.warn("Failed to load aggregate shortcuts config: #{e.message}")
          end

          def discover_aggregates
            @aggregates = []

            Rails.root.glob('app/contexts/**/aggregate.rb').each do |file|
              require file
              parts = file.to_s.split('contexts/').last.split('/')
              context = parts[0]
              subject = parts[1]

              class_name = "#{context.camelize}::#{subject.camelize}::Aggregate"
              klass = class_name.constantize

              next unless klass < Yes::Core::Aggregate

              @aggregates << {
                context: context.camelize,
                subject: subject.camelize,
                class: klass,
                class_name: class_name
              }
            rescue NameError, LoadError => e
              Rails.logger.debug { "Skipping #{file}: #{e.message}" }
            end
          end

          def create_shortcuts
            @shortcuts = {}
            context_modules = {}

            @aggregates.each do |agg|
              context_abbr = abbreviate_context(agg[:context])
              subject_abbr = abbreviate_subject(agg[:subject])

              # Create context module alias if not exists
              unless context_modules[context_abbr]
                if Object.const_defined?(context_abbr)
                  Rails.logger.warn("Shortcut conflict: #{context_abbr} already defined, skipping #{agg[:context]}")
                  next
                end

                context_module = agg[:context].constantize
                Object.const_set(context_abbr, context_module)
                context_modules[context_abbr] = context_module
              end

              # Create subject constant within context module
              context_mod = context_modules[context_abbr]
              if context_mod.const_defined?(subject_abbr)
                Rails.logger.warn("Shortcut conflict: #{context_abbr}::#{subject_abbr} already defined")
                next
              end

              context_mod.const_set(subject_abbr, agg[:class])

              shortcut_name = "#{context_abbr}::#{subject_abbr}"
              @shortcuts[shortcut_name] = agg[:class_name]
            end
          end

          def abbreviate_context(context)
            return @context_overrides[context] if @context_overrides[context]

            # Extract capital letters from CamelCase
            # ApprenticeshipPresentation → AP
            # CompanyManagement → CM
            context.scan(/[A-Z]/).join
          end

          def abbreviate_subject(subject)
            return @subject_overrides[subject] if @subject_overrides[subject]

            # First try capital letters
            capitals = subject.scan(/[A-Z]/).join
            return capitals if capitals.length > 1

            # Otherwise use first 4 characters
            subject[0..3]
          end

          def define_helper_method
            # Define global helper method for console
            Object.class_eval do
              define_method(:shortcuts) do |filter = nil|
                Yes::Core::Utils::AggregateShortcuts.display(filter)
                nil # Don't return anything to avoid console clutter
              end
            end
          end
        end
      end
    end
  end
end
