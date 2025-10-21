module Yes
  module Core
    class Railtie < Rails::Railtie
      config.after_initialize do |app|
        # Find all aggregates and register their public read models
        Rails.root.glob('app/contexts/**/**/aggregate.rb').each do |file|
          require file
          context, aggregate = file.to_s.split('contexts/').last.split('/')
          klass = "#{context.camelize}::#{aggregate.camelize}::Aggregate".constantize

          if klass.read_model_public?
            app.config.yes_read_api.read_models ||= []
            app.config.yes_read_api.read_models << klass.read_model_name.pluralize
          end

          # Also register the template read model if the aggregate is draftable and the changes read model is public
          if klass.draftable? && klass.changes_read_model_public?
            app.config.yes_read_api.read_models ||= []
            app.config.yes_read_api.read_models << klass.changes_read_model_name.pluralize
          end
        end
      end

      # Load aggregate shortcuts when Rails console starts
      console do
        Yes::Core::AggregateShortcuts.load!
      end
    end
  end
end
