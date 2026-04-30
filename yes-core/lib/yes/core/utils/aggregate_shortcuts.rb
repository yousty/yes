# frozen_string_literal: true

module Yes
  module Core
    module Utils
      # Provides convenient shortcuts for accessing aggregate classes in Rails console.
      # @example Multi-capital subjects use capitals-only abbreviations
      #   # Instead of: ApprenticeshipPresentation::ContactInfo::Aggregate.new(id)
      #   # Use: AP::CI.new(id)
      # @example Single-capital subjects keep the full name
      #   # Instead of: TaskFlow::Board::Aggregate.new(id)
      #   # Use: TF::Board.new(id)
      class AggregateShortcuts
        class << self
          # Load aggregate shortcuts in Rails console.
          # Creates fresh shortcut modules (e.g. TF) and assigns aggregate classes
          # as constants on them. Shortcut modules are NOT aliases of the real
          # context modules, so shortcut constants cannot collide with the
          # aggregates' own namespace modules.
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

          # Display shortcuts in a formatted table.
          #
          # Writes directly to STDOUT (via Kernel#puts) rather than the Rails logger
          # so the output is readable in any environment — Rails consoles in
          # production typically configure structured / JSON loggers that would
          # otherwise wrap each line in a JSON envelope.
          #
          # @param filter [String, nil] Optional filter
          # rubocop:disable Rails/Output
          def display(filter = nil)
            shortcuts = list(filter)

            if shortcuts.empty?
              puts "No shortcuts found#{" for '#{filter}'" if filter}."
              return
            end

            max_shortcut_length = shortcuts.keys.map(&:length).max
            separator = '=' * (max_shortcut_length + 70)

            puts "\nAvailable Aggregate Shortcuts:"
            puts separator
            shortcuts.sort.each do |shortcut, full_path|
              puts "#{shortcut.ljust(max_shortcut_length)} → #{full_path}"
            end
            puts separator
            puts "\nUsage: #{shortcuts.keys.first}.new(id)"
          end
          # rubocop:enable Rails/Output

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

              # Build (or reuse) a fresh container module for the context shortcut.
              # We deliberately do NOT alias the real context module: doing so would
              # mean shortcut constants (e.g. TF::Board) collide with the real
              # namespace modules of the aggregates themselves (TaskFlow::Board).
              unless context_modules[context_abbr]
                if Object.const_defined?(context_abbr)
                  Rails.logger.warn("Shortcut conflict: #{context_abbr} already defined, skipping #{agg[:context]}")
                  next
                end

                shortcut_module = Module.new
                Object.const_set(context_abbr, shortcut_module)
                context_modules[context_abbr] = shortcut_module
              end

              # Create subject constant within the shortcut container.
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

            # Multi-capital CamelCase names get a capitals-only abbreviation
            # (ContactInfo → CI). Single-capital names (Task, Board, Location)
            # use the full subject name to avoid awkward truncations like
            # "Boar" or shortcut collisions when the truncation matches the
            # subject's own namespace module (e.g. TaskFlow::Task).
            capitals = subject.scan(/[A-Z]/).join
            return capitals if capitals.length > 1

            subject
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
