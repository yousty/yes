# frozen_string_literal: true

module Yes
  module Core
    class Railtie < Rails::Railtie
      config.active_job.custom_serializers << Yes::Core::ActiveJobSerializers::DryStructSerializer
      config.active_job.custom_serializers << Yes::Core::ActiveJobSerializers::CommandGroupSerializer

      # Runs before any initializers are run
      config.before_configuration do
        PgEventstore.configure do |config|
          config.subscription_pull_interval = 0.5
          config.event_class_resolver = Yes::Core::EventClassResolver.new
          # Order of middlewares is important, :with_indifferent_access must come first
          config.middlewares = {
            with_indifferent_access: Yes::Core::Middlewares::WithIndifferentAccess.new,
            timestamp: Yes::Core::Middlewares::Timestamp.new
          }
        end
      end

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

      initializer 'yes-core.config' do |_app|
        unless Rails.env.test?
          Yes::Core.configure do |config|
            config.logger ||= Rails.logger
          end
        end

        PgEventstore.logger ||= Rails.logger if ENV['PG_ES_LOGGING'] == 'true'
      end

      # The one misconfiguration Middlewares.for_write cannot fix by itself: a decrypting encryptor registered
      # without its write-only twin. for_write then falls back to the full list, so writes stay CORRECT - they
      # just keep paying an encryptor key lookup and decrypt per encrypted event, for data nobody reads.
      # Warned about once at boot rather than on every append.
      config.after_initialize do
        middlewares = PgEventstore.config.middlewares
        next unless middlewares.key?(Yes::Core::Middlewares::ENCRYPTOR)
        next if middlewares.key?(Yes::Core::Middlewares::WRITE_ENCRYPTOR)

        Rails.logger.warn(
          'PgEventstore middleware :encryptor is registered without :write_encryptor, so append_to_stream ' \
          'decrypts every event it returns. Register both with Yes::Core::Middlewares.register_encryptor.'
        )
      end

      # Load aggregate shortcuts when Rails console starts
      console do
        Yes::Core::Utils::AggregateShortcuts.load!
      end
    end
  end
end
