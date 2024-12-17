# frozen_string_literal: true

module Yes
  class Railtie < Rails::Railtie
    config.after_initialize do |app|
      # Find all aggregates and register their public read models
      Dir.glob(Rails.root.join('app/contexts/**/**/aggregate.rb')).each do |file|
        require file
        context, aggregate = file.split('contexts/').last.split('/')
        klass = "#{context.camelize}::#{aggregate.camelize}::Aggregate".constantize

        if klass.read_model_public?
          app.config.yousty_read_api.read_models ||= []
          app.config.yousty_read_api.read_models << klass.read_model_name.pluralize
        end
      end
    end
  end
end
