# frozen_string_literal: true

namespace :db do
  namespace :structure do
    desc 'Load structure.sql into database using Docker PostgreSQL container'
    task load: :environment do
      config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).first
      database = config.database

      puts "Loading structure.sql into #{database} database..."

      # Use Docker container's psql to load structure.sql
      system("docker exec -i yes-postgres-1 psql -U postgres -d #{database} < #{Rails.root.join('db/structure.sql')}")

      puts 'Structure loaded successfully!'
    end
  end
end
